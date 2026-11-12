// Mapping grid behavior: the Relevant/All/Mapped/Pending filter, scroll to a
// class or card, and in-place patches from the server (ADR-170 moved it out
// of mod_mapping.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  function now() {
    return window.performance ? performance.now() : Date.now();
  }

  // Relevant filter: open or close a class's compact rows client-side.
  // The rows are bound inputs already, so nothing is rebuilt (ADR-137).
  // The jQuery events make Shiny recheck which outputs are hidden.
  function setMoreGroupOpen(group, open) {
    group.classList.toggle('is-open', open);
    var btn = group.querySelector('.mapping-more');
    if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    window.jQuery(group).trigger(open ? 'shown' : 'hidden');
    markDeferredOrderStale();
  }

  // Relevant / All / Mapped / Pending in the browser (ADR-157). The grid
  // holds every card, so a switch rebuilds nothing. The rules follow
  // keep_by_mapped_filter() and collapse_mapping_term(): the server keeps
  // the state classes current (saira-toggle-field-mapped) and marks the
  // terms that can collapse (data-collapse).
  function keepByFilter(mode, el) {
    if (mode === 'mapped') return el.classList.contains('field-mapped');
    if (mode === 'pending') {
      return el.classList.contains('field-required-missing') ||
        el.classList.contains('field-attention');
    }
    return true;
  }

  function cardTerm(card, prefix) {
    return card.id.slice((prefix + 'fieldcard_').length);
  }

  function collapseByFilter(mode, card, prefix) {
    if (mode !== 'relevant' || card.dataset.collapse !== 'true' ||
        !card.classList.contains('field-unmapped')) {
      return false;
    }
    var fixed = document.getElementById(prefix + 'usecustom_' + cardTerm(card, prefix));
    return !(fixed && fixed.checked);
  }

  // Write only a changed value: each write is a DOM mutation.
  function setHidden(el, hide) {
    if (el.hidden !== hide) el.hidden = hide;
  }

  function setText(el, text) {
    if (el.textContent !== text) el.textContent = text;
  }

  function setMoreGroupText(group, terms) {
    setHidden(group, terms.length === 0);
    setText(group.querySelector('.mapping-more-label'), terms.length + ' ' +
      (terms.length === 1 ? group.dataset.one : group.dataset.other));
    setText(group.querySelector('.mapping-more-terms'), terms.join(', '));
  }

  // Classes only, no card moves: a moved card connects its tooltips again,
  // and the browser styles and lays it out from zero. The CSS order puts the
  // collapsed cards after the line.
  function applyMappingFilter(prefix) {
    var picked = document.querySelector('input[name="' + prefix + 'mapped_filter"]:checked');
    var out = document.getElementById(prefix + 'mapping_ui');
    if (!picked || !out) return;
    var mode = picked.value;
    out.querySelectorAll('.field-row').forEach(function (row) {
      setHidden(row, !keepByFilter(mode, row));
    });
    out.querySelectorAll('.mapping-card-grid').forEach(function (grid) {
      var group = grid.querySelector(':scope > .mapping-more-group');
      if (!group) return;
      var terms = [];
      grid.querySelectorAll(':scope > .field-card').forEach(function (card) {
        setHidden(card, !keepByFilter(mode, card));
        var collapse = collapseByFilter(mode, card, prefix);
        card.classList.toggle('field-card-compact', collapse);
        card.classList.toggle('field-card-collapsed', collapse);
        if (collapse) terms.push(cardTerm(card, prefix));
      });
      setMoreGroupText(group, terms);
    });
    markDeferredOrderStale();
  }

  // The filter for one card after a server patch changes its state classes.
  // Only the visibility follows: a compact row that gets a column stays a row
  // until the next render (ADR-137), and a card the user opened stays open.
  function projectCard(el) {
    var m = /^(.*-)field(card|row)_/.exec(el.id);
    var picked = m && document.querySelector('input[name="' + m[1] + 'mapped_filter"]:checked');
    if (picked) setHidden(el, !keepByFilter(picked.value, el));
  }

  // A card or row that the filter hides cannot scroll into view.
  // Relevant keeps every card, so switch to it.
  function revealFiltered(el) {
    var m = /^(.*-)field(card|row)_/.exec(el.id);
    var group = m && document.getElementById(m[1] + 'mapped_filter');
    var relevant = group && group.querySelector('input[value="relevant"]');
    if (!relevant) return;
    relevant.checked = true;
    window.jQuery(group).trigger('change');
  }

  function flash(el) {
    el.classList.remove('field-card-flash');
    void el.offsetWidth;
    el.classList.add('field-card-flash');
    setTimeout(function () {
      el.classList.remove('field-card-flash');
    }, 2200);
  }

  // Selectize takes about half of the grid mount, ~6 ms a card (ADR-197).
  // The grid comes with the selectize config of each card under another
  // attribute, so Shiny binds plain selects with their values at once: the
  // auto-map and the counts see every card. A static copy of the selectize
  // box keeps the card size until selectize starts. The cards in view start
  // before the first paint, the others in small batches, nearest first. A
  // card that the pointer or the focus reaches starts at once.
  var DEFER_ATTR = 'data-saira-defer-for';
  var STANDIN_CLASS = 'saira-selectize-standin';
  var deferred = [];
  var deferredBox = null;
  var deferredOrderStale = false;
  var deferredTask = null;
  var deferredSetupPrefix = null;

  function deferSelectize(value) {
    if (!value || typeof value.html !== 'string') return false;
    var html = value.html
      .replace(/ data-for="([^"]*-map_[A-Za-z]+)"/g, ' ' + DEFER_ATTR + '="$1"')
      // selectize leaves out the empty option, so a plain multiple select
      // must not report it either: jQuery .val() skips a disabled option.
      // Without this, a card with no column reports [""], not [].
      .replace(/(<select id="[^"]*-map_[A-Za-z]+"[^>]* multiple[^>]*>\s*<option value="")/g, '$1 disabled');
    if (html === value.html) return false;
    value.html = html;
    return true;
  }

  // A scroll or a filter change moves the cards nearest to the view.
  function markDeferredOrderStale() {
    if (deferred.length) deferredOrderStale = true;
  }

  function resetDeferred() {
    if (deferredTask !== null) clearTimeout(deferredTask);
    deferredTask = null;
    deferred = [];
    deferredOrderStale = false;
  }

  // The classes and the inline sizes that selectize gives its box.
  function buildStandin(sel) {
    var picked = [];
    var placeholder = '';
    for (var i = 0; i < sel.options.length; i++) {
      var opt = sel.options[i];
      if (opt.value === '') placeholder = opt.text;
      else if (opt.selected) picked.push(opt.text);
    }
    var full = !sel.multiple && picked.length > 0;
    var control = document.createElement('div');
    control.className = 'shiny-input-select selectize-control ' +
      (sel.multiple ? 'multi' : 'single') + ' plugin-selectize-plugin-a11y ' + STANDIN_CLASS;
    var box = document.createElement('div');
    box.className = 'selectize-input items has-options' +
      (full ? ' full' : ' not-full') + (picked.length ? ' has-items' : '');
    picked.forEach(function (text) {
      var item = document.createElement('div');
      item.className = 'item';
      item.textContent = text;
      box.appendChild(item);
    });
    var field = document.createElement('input');
    field.type = 'text';
    field.readOnly = true;
    window.jQuery(field).attr(window.sairaAutofillOff || { autocomplete: 'off' });
    if (picked.length || !placeholder) {
      field.style.width = '4px';
      if (full) {
        field.style.opacity = '0';
        field.style.position = 'absolute';
        field.style.left = '0px';
      }
    } else {
      field.placeholder = placeholder;
    }
    box.appendChild(field);
    control.appendChild(box);
    return control;
  }

  // selectize sizes the empty field to its placeholder text plus 8 px, and
  // the card CSS centers the text in the field. One measure per render.
  var measureContext = null;
  var placeholderWidths = {};

  function insertStandin(sel) {
    var control = buildStandin(sel);
    sel.insertAdjacentElement('afterend', control);
    var field = control.querySelector('input[placeholder]');
    if (!field) return;
    var text = field.placeholder;
    if (!(text in placeholderWidths)) {
      var style = window.getComputedStyle(field);
      measureContext = measureContext || document.createElement('canvas').getContext('2d');
      measureContext.font = style.fontStyle + ' ' + style.fontWeight + ' ' +
        style.fontSize + ' ' + style.fontFamily;
      placeholderWidths[text] = measureContext.measureText(text).width + 8;
    }
    field.style.width = placeholderWidths[text] + 'px';
  }

  function startSelectize(sel, open) {
    var at = deferred.indexOf(sel);
    if (at !== -1) deferred.splice(at, 1);
    var cfg = sel.parentElement && sel.parentElement.querySelector('script[' + DEFER_ATTR + ']');
    var binding = window.jQuery(sel).data('shiny-input-binding');
    if (!cfg || !binding) return;
    var standin = sel.nextElementSibling;
    var focused = false;
    if (standin && standin.classList.contains(STANDIN_CLASS)) {
      focused = standin.contains(document.activeElement);
      standin.remove();
    }
    sel.style.display = '';
    cfg.setAttribute('data-for', cfg.getAttribute(DEFER_ATTR));
    cfg.removeAttribute(DEFER_ATTR);
    // The same call that Shiny makes before it binds the select.
    binding.initialize(sel);
    if ((focused || open) && sel.selectize) sel.selectize.focus();
  }

  // Order by the distance in pixels to the visible part of the grid. A
  // hidden card (filter, closed line) comes last. Returns how many cards
  // are in view.
  function sortDeferred() {
    var r = deferredBox && deferredBox.isConnected ?
      deferredBox.getBoundingClientRect() : { top: 0, bottom: window.innerHeight };
    var top = Math.max(0, r.top);
    var bottom = Math.min(window.innerHeight, r.bottom);
    var scored = deferred.filter(function (sel) {
      return sel.isConnected;
    }).map(function (sel) {
      var rect = (sel.nextElementSibling || sel).getBoundingClientRect();
      var d = rect.height === 0 ? 1e9 : Math.max(0, top - rect.bottom, rect.top - bottom);
      return { sel: sel, d: d };
    });
    scored.sort(function (a, b) {
      return a.d - b.d;
    });
    deferred = scored.map(function (x) {
      return x.sel;
    });
    return scored.filter(function (x) {
      return x.d === 0;
    }).length;
  }

  // Not requestIdleCallback: Firefox does not run it on a still page, even
  // with a timeout, so the batches stopped until the next pointer move.
  function scheduleDeferred() {
    if (deferredTask === null && deferred.length) deferredTask = setTimeout(runDeferredBatch, 0);
  }

  // A slice of about 8 ms leaves the page free to answer a click or a key
  // in the same frame.
  function runDeferredBatch() {
    deferredTask = null;
    if (deferredOrderStale) {
      deferredOrderStale = false;
      sortDeferred();
    }
    var start = now();
    while (deferred.length && now() - start < 8) startSelectize(deferred[0]);
    scheduleDeferred();
  }

  function setupDeferred(out) {
    resetDeferred();
    deferredBox = out.closest('.mapping-scroll-container') || out;
    placeholderWidths = {};
    out.querySelectorAll('script[' + DEFER_ATTR + ']').forEach(function (cfg) {
      var sel = document.getElementById(cfg.getAttribute(DEFER_ATTR));
      if (!sel || sel.tagName !== 'SELECT') return;
      sel.style.display = 'none';
      insertStandin(sel);
      deferred.push(sel);
    });
    deferred.slice(0, sortDeferred()).forEach(function (sel) {
      startSelectize(sel);
    });
    scheduleDeferred();
  }

  // The handlers are delegated, so one registration serves every render.
  behavior.mappingGrid = function () {
    if (window.__sairaMappingScrollRegistered) return;
    window.__sairaMappingScrollRegistered = true;

    // jQuery, not addEventListener: a server update of the radio triggers
    // a jQuery change event, which a native listener misses.
    window.jQuery(document).on('change', '.shiny-input-radiogroup', function () {
      var m = /^(.*-)mapped_filter$/.exec(this.id || '');
      if (m) applyMappingFilter(m[1]);
    });

    function openCollapsedCard(prefix, term) {
      var card = document.getElementById(prefix + 'fieldcard_' + term);
      if (!card || !card.classList.contains('field-card-collapsed')) return;
      card.classList.remove('field-card-compact', 'field-card-collapsed');
      var grid = card.parentElement;
      var group = grid.querySelector(':scope > .mapping-more-group');
      if (!group) return;
      var terms = [];
      grid.querySelectorAll(':scope > .field-card.field-card-collapsed').forEach(function (c) {
        terms.push(cardTerm(c, prefix));
      });
      setMoreGroupText(group, terms);
    }

    // A fixed value turned on by a guide import does not change the filter,
    // so the row stayed collapsed with the value out of sight. Only that row
    // opens: a row that got a column stays a row (ADR-137).
    window.jQuery(document).on('change', 'input[type="checkbox"]', function () {
      var m = /^(.*-)usecustom_(.*)$/.exec(this.id || '');
      if (!m || !this.checked) return;
      openCollapsedCard(m[1], m[2]);
    });

    // A wide card (dynamicProperties keys, measurement type and unit) has
    // inputs for each picked column, and a compact row hides them. So a wide
    // row that gets a column opens.
    window.jQuery(document).on('change', 'select', function () {
      var m = /^(.*-)map_(.*)$/.exec(this.id || '');
      if (!m || !window.jQuery(this).val() || !window.jQuery(this).val().length) return;
      var card = document.getElementById(m[1] + 'fieldcard_' + m[2]);
      if (card && card.classList.contains('field-card-wide')) openCollapsedCard(m[1], m[2]);
    });

    // The upload auto-map patches the cards in place, so the server asks for
    // the filter once after it, as the grid render below does.
    Shiny.addCustomMessageHandler('saira-mapping-apply-filter', function (payload) {
      if (payload && payload.prefix) applyMappingFilter(payload.prefix);
    });

    // A rebuild can start before the server gets a filter switch, so the
    // new grid gets the filter on screen.
    window.jQuery(document).on('shiny:value', function (ev) {
      var m = /^(.*-)mapping_ui$/.exec(ev.target.id || '');
      if (m) {
        resetDeferred();
        deferredSetupPrefix = deferSelectize(ev.value) ? m[1] : null;
        setTimeout(function () {
          applyMappingFilter(m[1]);
        }, 0);
      }
    });

    document.addEventListener('click', function (ev) {
      var more = ev.target.closest('.mapping-more');
      if (more) {
        var group = more.closest('.mapping-more-group');
        setMoreGroupOpen(group, !group.classList.contains('is-open'));
        return;
      }
      // 'Fixed value' on a compact row: show the full card in place.
      var expand = ev.target.closest('.field-compact-expand');
      if (expand) {
        expand.closest('.field-card').classList.remove('field-card-compact');
        return;
      }
      // Island suggestion in the establishment assistant (ADR-143):
      // the user applies it, the app never fills it in silently.
      var island = ev.target.closest('.est-island-apply, .est-island-undo');
      if (island) {
        var wrap = island.closest('.est-island-suggest');
        var apply = island.classList.contains('est-island-apply');
        window.jQuery(document.getElementById(wrap.dataset.target))
          .val(apply ? 'introduced' : '').trigger('change');
        wrap.classList.toggle('is-applied', apply);
      }
    });

    document.addEventListener('change', function (ev) {
      var sel = ev.target;
      if (!sel.id || sel.id.indexOf('est_island_means_') === -1) return;
      var wrap = document.querySelector('.est-island-suggest[data-target="' + sel.id + '"]');
      if (wrap) wrap.classList.toggle('is-applied', sel.value === 'introduced');
    });

    Shiny.addCustomMessageHandler('saira-mapping-scroll-to-class', function (payload) {
      var id = payload && payload.anchor_id;
      if (!id) return;
      // Poll until the target element exists, then scroll. A class anchor
      // is already in the DOM. A new term card waits for the grid rebuild
      // (~50 selectize inputs), which can take a few seconds, so poll on a
      // time budget, not a fixed frame count.
      var deadline = now() + 8000;
      (function tryScroll() {
        var el = document.getElementById(id);
        if (!el) {
          if (now() < deadline) window.requestAnimationFrame(tryScroll);
          return;
        }
        if (el.hidden) revealFiltered(el);
        // A card collapsed by the Relevant filter is hidden (display: none)
        // while its line is closed, and cannot scroll into view.
        var group = el.classList.contains('field-card-collapsed') &&
          el.parentElement.querySelector(':scope > .mapping-more-group');
        if (group && !group.classList.contains('is-open')) setMoreGroupOpen(group, true);
        el.scrollIntoView({ behavior: 'smooth', block: payload.block || 'start' });
        // The 'next pending' button flashes the card, so it stands out from
        // its neighbours. Outline only, so nothing shifts.
        if (payload.flash) flash(el);
      })();
    });

    // Patch the class pills' state dots and the pending counter in place.
    // Same reason as saira-toggle-field-mapped below: a render of the pill
    // bar would recreate its actionButtons on every mapping change.
    Shiny.addCustomMessageHandler('saira-mapping-triage', function (payload) {
      if (!payload) return;
      // The first push can arrive before renderUI puts the pill bar in the
      // DOM (auto-map writes the mapping as the tab is drawn), so poll on a
      // short budget as the scroll handler does.
      var deadline = now() + 3000;
      (function apply() {
        var counter = document.getElementById(payload.count_id);
        if (!counter) {
          if (now() < deadline) window.requestAnimationFrame(apply);
          return;
        }
        counter.textContent = payload.count > 0 ? String(payload.count) : '';
        (payload.dots || []).forEach(function (item) {
          var dot = document.getElementById(item.id);
          if (!dot) return;
          dot.className = 'pill-state-dot is-' + item.state;
          dot.title = item.title || '';
        });
        var btn = document.getElementById(payload.button_id);
        if (btn) btn.classList.toggle('is-idle', !(payload.count > 0));
        Object.keys(payload.filters || {}).forEach(function (key) {
          var chip = document.getElementById(payload.filter_prefix + key);
          if (!chip) return;
          var n = payload.filters[key];
          chip.textContent = String(n);
          chip.classList.toggle('is-act', chip.dataset.action === 'true' && n > 0);
        });
      })();
    });

    // The first card bound means that the grid is in the DOM. The microtask
    // runs after Shiny binds the other cards, and before the first paint.
    window.jQuery(document).on('shiny:bound', function (ev) {
      var prefix = deferredSetupPrefix;
      if (!prefix || ev.bindingType !== 'input') return;
      if ((ev.target.id || '').indexOf(prefix + 'map_') !== 0) return;
      deferredSetupPrefix = null;
      Promise.resolve().then(function () {
        var out = document.getElementById(prefix + 'mapping_ui');
        if (out) setupDeferred(out);
      });
    });

    // A server update (auto-map, Reset, a guide import) reaches the plain
    // select, so the copy shows the new value until selectize starts.
    window.jQuery(document).on('change', 'select', function () {
      var standin = this.nextElementSibling;
      if (standin && standin.classList.contains(STANDIN_CLASS)) {
        standin.remove();
        insertStandin(this);
      }
    });

    // A touch sends its later events to the copy that startSelectize
    // removes, so selectize never gets the tap. The touch opens it here.
    function startFromEvent(ev) {
      var standin = ev.target.closest && ev.target.closest('.' + STANDIN_CLASS);
      if (standin && standin.previousElementSibling) {
        startSelectize(standin.previousElementSibling, ev.pointerType === 'touch');
      }
    }
    // The pointer enters a card before the click, so a mouse click reaches
    // selectize.
    document.addEventListener('pointerover', startFromEvent, true);
    document.addEventListener('focusin', startFromEvent, true);
    document.addEventListener('scroll', markDeferredOrderStale, { capture: true, passive: true });

    // Tell the server the field cards are bound, once per grid render. The
    // upload auto-map waits for this signal: a card value alone may not
    // change (a new file can leave scientificName empty again), and an
    // unchanged input never reaches the server. The timer runs after Shiny
    // has queued the card values, so they arrive first.
    var cardsBoundTimer = null;
    window.jQuery(document).on('shiny:bound', function (ev) {
      if (ev.bindingType !== 'input' || cardsBoundTimer) return;
      var m = /^(.*-)map_[A-Za-z]+$/.exec(ev.target.id || '');
      if (!m || !ev.target.closest('.mapping-scroll-container')) return;
      cardsBoundTimer = setTimeout(function () {
        cardsBoundTimer = null;
        Shiny.setInputValue(m[1] + 'cards_bound', Date.now());
      }, 0);
    });

    // Toggle a field card's mapped border without a render of the whole
    // grid. Used for fixed-value terms whose free-text read is isolated
    // (ADR-098): the server recomputes is_field_mapped() after typing
    // settles and flips the class here, as the next render would.
    // A change of many cards sends them in one message, as {cards: [...]}.
    Shiny.addCustomMessageHandler('saira-toggle-field-mapped', function (payload) {
      var cards = payload && payload.cards ? payload.cards : [payload];
      cards.forEach(toggleFieldMapped);
    });

    function toggleFieldMapped(payload) {
      var el = payload && payload.id && document.getElementById(payload.id);
      if (!el) return;
      el.classList.toggle('field-mapped', !!payload.mapped);
      el.classList.toggle('field-unmapped', !payload.mapped);
      // Same for the state modifier: it is decided at render time, and the
      // grid does not render again on a selection, so a required card would
      // keep its red border after it is filled.
      el.classList.remove('field-required-missing', 'field-attention');
      if (payload.state) el.classList.add(payload.state);
      // A taxon card derived from scientificName holds its select and its
      // lock note, so the lock switches here and not in a grid render.
      if (typeof payload.locked === 'boolean') {
        var note = el.querySelector('.taxon-lock-note');
        var pick = el.querySelector('.taxon-lock-select');
        if (note) setHidden(note, !payload.locked);
        if (pick) setHidden(pick, payload.locked);
      }
      // Mapped and Pending read these classes, so a card that no longer
      // matches the picked filter leaves the screen now.
      projectCard(el);
      // Sync the status badge (e.g. -> EDITADO) without a render. The badge
      // span carries a stable .field-status-badge hook: create it if the
      // term had no badge, remove it when the recomputed badge is null.
      var badge = payload.badge;
      if (!badge) return;
      var span = el.querySelector('.field-status-badge');
      if (!badge.show) {
        if (span && span.parentNode) span.parentNode.removeChild(span);
        return;
      }
      if (!span) {
        var row = el.querySelector('.field-header-row');
        if (!row) return;
        span = document.createElement('span');
        row.appendChild(span);
      }
      span.className = badge.class;
      span.title = badge.title || '';
      span.textContent = badge.label || '';
    }
  };

  // bslib closes the sidebar only below 576 px. Below 1100 px the 280 px
  // sidebar squeezes the grid, so it starts closed once; the user can open it.
  function closeNarrowSidebar() {
    if (!window.matchMedia('(max-width: 1099.98px)').matches) return;
    var Sidebar = window.bslib && window.bslib.Sidebar;
    var aside = document.querySelector('.mapping-sidebar');
    var layout = aside && aside.closest('.bslib-sidebar-layout');
    var instance = layout && Sidebar && Sidebar.getInstance(layout);
    if (instance) instance.toggle('close', true);
  }
  window.jQuery(document).one('shiny:connected', closeNarrowSidebar);
})();

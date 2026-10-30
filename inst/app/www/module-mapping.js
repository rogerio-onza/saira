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

    // A rebuild can start before the server gets a filter switch, so the
    // new grid gets the filter on screen.
    window.jQuery(document).on('shiny:value', function (ev) {
      var m = /^(.*-)mapping_ui$/.exec(ev.target.id || '');
      if (m) {
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
    Shiny.addCustomMessageHandler('saira-toggle-field-mapped', function (payload) {
      var el = payload && payload.id && document.getElementById(payload.id);
      if (!el) return;
      el.classList.toggle('field-mapped', !!payload.mapped);
      el.classList.toggle('field-unmapped', !payload.mapped);
      // Same for the state modifier: it is decided at render time, and the
      // grid does not render again on a selection, so a required card would
      // keep its red border after it is filled.
      el.classList.remove('field-required-missing', 'field-attention');
      if (payload.state) el.classList.add(payload.state);
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
    });
  };
})();

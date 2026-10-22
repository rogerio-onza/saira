// Names page behavior: the report table cells, its search and page length,
// and the review modals (ADR-170 moved it out of mod_validate_names.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  function text(value) {
    return String(value === null || value === undefined ? '' : value);
  }

  function escapeHtml(value) {
    return $('<div/>').text(value).html();
  }

  function onModalHidden(el, callback) {
    var host = el.closest('.modal') || el;
    host.addEventListener('hidden.bs.modal', callback, { once: true });
  }

  // A review modal can close while Bootstrap still holds its backdrop. The
  // server asks for this cleanup after it removes the modal.
  behavior.namesBackdropCleanup = function () {
    $(function () {
      if (window.__vnCleanupRegistered) return;
      window.__vnCleanupRegistered = true;
      // Shiny rejects a handler that takes no argument.
      Shiny.addCustomMessageHandler('vnCleanupBackdrop', function (msg) {
        if (!document.body) return;
        document.body.classList.remove('vn-review-open', 'modal-open');
        document.querySelectorAll('.modal-backdrop').forEach(function (el) {
          el.remove();
        });
        document.body.style.removeProperty('overflow');
        document.body.style.removeProperty('padding-right');
      });
    });
  };

  var STATUS_BADGE = {
    accepted: 'badge-success',
    accepted_manual: 'badge-success',
    manual_revision: 'badge-warning',
    synonym: 'badge-info',
    not_found: 'badge-error',
    ambiguous: 'badge-warning',
    ignored: 'badge-muted'
  };

  var STATUS_ROW = {
    accepted: 'vn-row-accepted',
    accepted_manual: 'vn-row-accepted',
    manual_revision: 'vn-row-manual',
    synonym: 'vn-row-synonym',
    not_found: 'vn-row-not-found',
    ambiguous: 'vn-row-ambiguous',
    ignored: 'vn-row-ignored'
  };

  behavior.namesStatusBadge = function (cfg) {
    return function (data, type) {
      var status = text(data).toLowerCase();
      if (type !== 'display') return status;
      var cls = STATUS_BADGE[status] || 'badge-muted';
      var label = cfg.labels[status] || String(data || '');
      return '<span class="vn-status-badge ' + cls + '">' + escapeHtml(label) + '</span>';
    };
  };

  // The hidden columns carry the row state: 1 status, 3 original name,
  // 4 sensitive category, 5 resolved name, 6 invasive origin class,
  // 7 invasive reasons.
  behavior.namesScientificCell = function (cfg) {
    return function (data, type, row) {
      if (type !== 'display') return data;
      if (data === null || data === undefined) return '';
      var escaped = escapeHtml(String(data));
      var content = '<span class="vn-cell-scientific" title="' + escaped + '">' + escaped + '</span>';

      var status = text(row[1]).toLowerCase();
      var original = text(row[3]);
      if (status === 'manual_revision' && original.trim().length > 0) {
        content += '<div class="vn-cell-review-original"><em>' + escapeHtml(String(cfg.replacedPrefix)) +
          ' ' + escapeHtml(original) + '</em></div>';
      }

      var sensitive = text(row[4]).trim();
      var sn = encodeURIComponent(text(row[5]));
      if (sensitive.length > 0) {
        content += '<div class="vn-cell-sensitive"><span class="vn-status-badge badge-warning ' +
          'vn-sensitive-trigger" role="button" tabindex="0" data-sname="' + sn + '">' +
          escapeHtml(String(cfg.sensitiveLabel)) + ' · ' + escapeHtml(sensitive) + '</span></div>';
      } else {
        content += '<div class="vn-cell-sensitive"><span class="vn-sensitive-trigger vn-sensitive-add" ' +
          'role="button" tabindex="0" data-sname="' + sn + '">+ ' +
          escapeHtml(String(cfg.sensitiveMark)) + '</span></div>';
      }

      var invasive = text(row[6]).trim();
      if (invasive.length > 0) {
        var alien = invasive === 'alien';
        var label = alien ? cfg.invasiveLabel : cfg.translocatedLabel;
        var tip = alien ? cfg.invasiveTip : cfg.translocatedTip;
        var cls = alien ? 'badge-invasive' : 'badge-translocated';
        var tipEsc = escapeHtml(String(tip)).replace(/"/g, '&quot;');
        content += '<div class="vn-cell-invasive"><span class="vn-status-badge ' + cls + '" title="' +
          tipEsc + '">' + escapeHtml(String(label)) + '</span>';
        var detail = text(row[7]).trim();
        if (detail.length > 0) {
          detail.split('\n').forEach(function (line) {
            if (line.length === 0) return;
            content += '<div class="vn-cell-invasive-reason">' + escapeHtml(line) + '</div>';
          });
        }
        content += '</div>';
      }
      return content;
    };
  };

  behavior.namesTaxonomicCell = function () {
    return function (data, type) {
      if (type !== 'display') return data;
      if (data === null || data === undefined) return '';
      var escaped = escapeHtml(String(data));
      return '<span class="vn-cell-taxonomic" title="' + escaped + '">' + escaped + '</span>';
    };
  };

  behavior.namesRowClass = function () {
    var all = Object.keys(STATUS_ROW).map(function (key) {
      return STATUS_ROW[key];
    }).join(' ');
    return function (row, data) {
      var cls = STATUS_ROW[text(data[1]).toLowerCase()];
      $(row).removeClass(all);
      if (cls) $(row).addClass(cls);
    };
  };

  // DT callback: the custom search box and page length drive the table, and
  // the sensitivity badges open the sensitivity panel. The event namespace
  // makes a new render replace the old handlers.
  behavior.namesTableFilters = function (cfg, table) {
    var searchSelector = '#' + cfg.searchId;
    var pageSelector = '#' + cfg.pageId;
    var eventNs = '.vnReport.' + cfg.searchId.replace(/[^a-zA-Z0-9_-]/g, '');
    var $doc = $(document);

    $doc.off('input' + eventNs, searchSelector);
    $doc.off('keyup' + eventNs, searchSelector);
    $doc.off('search' + eventNs, searchSelector);
    $doc.off('change' + eventNs, pageSelector);
    $doc.off('click' + eventNs, '.vn-sensitive-trigger');
    $doc.off('keydown' + eventNs, '.vn-sensitive-trigger');

    var openSensitivity = function (el) {
      var sn = decodeURIComponent($(el).attr('data-sname') || '');
      if (sn.length > 0) Shiny.setInputValue(cfg.sensitivityId, sn, { priority: 'event' });
    };
    $doc.on('click' + eventNs, '.vn-sensitive-trigger', function () {
      openSensitivity(this);
    });
    $doc.on('keydown' + eventNs, '.vn-sensitive-trigger', function (e) {
      if (e.key === 'Enter' || e.key === ' ' || e.keyCode === 13 || e.keyCode === 32) {
        e.preventDefault();
        openSensitivity(this);
      }
    });

    var search = function () {
      table.search(String(this.value || '')).draw(false);
    };
    $doc.on('input' + eventNs, searchSelector, search);
    $doc.on('keyup' + eventNs, searchSelector, search);
    $doc.on('search' + eventNs, searchSelector, search);
    $doc.on('change' + eventNs, pageSelector, function () {
      var len = parseInt(this.value, 10);
      if (isNaN(len) || len <= 0) return;
      if (table.page.len() !== len) table.page.len(len);
      table.page('first').draw('page');
    });

    var $search = $(searchSelector);
    if ($search.length) table.search(String($search.val() || '')).draw(false);
    var $page = $(pageSelector);
    if ($page.length) {
      var selectedLen = parseInt($page.val(), 10);
      if (isNaN(selectedLen) || selectedLen <= 0) {
        selectedLen = table.page.len();
        $page.val(String(selectedLen));
      }
      table.page.len(selectedLen);
      table.page('first').draw('page');
    }
  };

  // The body class styles the page behind an open review modal.
  behavior.namesReviewModal = function (cfg) {
    var modalEl = document.getElementById(cfg.rootId);
    if (!modalEl) return;
    if (document.body) document.body.classList.add('vn-review-open');
    onModalHidden(modalEl, function () {
      if (document.body) document.body.classList.remove('vn-review-open');
    });
  };

  // Save stays off until the name differs from the original.
  behavior.namesReviewEdit = function (cfg) {
    var inputEl = document.getElementById(cfg.inputId);
    var btnEl = document.getElementById(cfg.saveId);
    if (!inputEl || !btnEl) return;
    var sync = function () {
      btnEl.disabled = String(inputEl.value || '').trim() === String(cfg.original || '').trim();
    };
    inputEl.addEventListener('input', sync);
    sync();
    window.setTimeout(function () {
      inputEl.focus();
      inputEl.select();
    }, 50);
  };

  // A click anywhere on the confirm block toggles its checkbox. Confirm stays
  // off until the box is checked.
  behavior.namesReviewConfirm = function (cfg) {
    var block = document.getElementById(cfg.blockId);
    var checkbox = document.getElementById(cfg.checkboxId);
    var confirmBtn = document.getElementById(cfg.confirmId);
    if (!block || !checkbox || !confirmBtn) return;
    var sync = function () {
      confirmBtn.disabled = !checkbox.checked;
    };
    block.addEventListener('click', function (e) {
      if (e.target && e.target.id === checkbox.id) return;
      checkbox.checked = !checkbox.checked;
      sync();
    });
    checkbox.addEventListener('change', sync);
    sync();
  };

  behavior.namesTableHeader = function () {
    return function (thead) {
      $(thead).find('th').each(function () {
        var $th = $(this);
        if ($th.find('.vn-th-content').length > 0) return;
        var label = $th.text();
        $th.html("<span class='vn-th-content'><span class='vn-th-label'>" + label +
          "</span><span class='vn-th-sort'>&#8597;</span></span>");
      });
    };
  };
})();

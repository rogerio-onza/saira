// Preview behavior: the Table view cells and the Problems mode controls
// (ADR-170 moved it out of mod_preview.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  // Quotes too: the value also goes into title="...".
  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function rowKey(d) {
    return d[0] + '|' + d[1];
  }

  // The controls of the Problems mode render per row, so one delegated
  // handler per control serves every row (as in Coordinates).
  behavior.previewFixControls = function (cfg) {
    var sendId = function (selector, inputId) {
      $(document).on('click', selector, function (e) {
        e.preventDefault();
        Shiny.setInputValue(inputId, parseInt(this.dataset.id, 10), { priority: 'event' });
      });
    };
    sendId('.preview-fix-use', cfg.useId);
    sendId('.preview-fix-blank', cfg.blankId);
    sendId('.preview-fix-undo', cfg.undoId);
    sendId('.preview-fix-other', cfg.otherId);

    $(document).on('click', '.preview-vocab-apply', function (e) {
      e.preventDefault();
      var item = $(this).closest('.preview-vocab-item');
      var sel = item.find('select')[0];
      if (!sel || !sel.value) return;
      appliedVocab = item[0].dataset.key;
      Shiny.setInputValue(cfg.vocabApplyId, { id: parseInt(this.dataset.id, 10), to: sel.value },
        { priority: 'event' });
    });

    // After an applied value, the next open value comes into view only when
    // the list hides it. The applied line stays above it, as in the row list.
    function revealNextVocab(list, key) {
      var done = $(list).children('.preview-vocab-item').filter(function () {
        return this.dataset.key === key;
      });
      var next = done.nextAll('.preview-vocab-item:not(.is-done)')[0];
      if (!next) return;
      var box = list.getBoundingClientRect();
      var rect = next.getBoundingClientRect();
      if (rect.top < box.top || rect.bottom > box.bottom) {
        list.scrollTop += next.previousElementSibling.getBoundingClientRect().top - box.top;
      }
    }

    // These lists render again after each correction, which returns them to
    // the top. The scroll position and the vocabulary choices not yet applied
    // are kept here and put back.
    var pickedVocab = {};
    var appliedVocab = null;
    var scrollLists = '.preview-vocab-list, .preview-copy-scroll';
    $(document).on('change', '.preview-vocab-item select', function () {
      var item = $(this).closest('.preview-vocab-item');
      pickedVocab[item.data('key')] = this.value;
      item.find('.preview-vocab-apply').prop('disabled', !this.value);
    });
    $(document).on('shiny:value', function (e) {
      var isVocab = e.name === cfg.vocabSectionId;
      if (!isVocab && e.name !== cfg.copiesSectionId) return;
      var output = e.target;
      var old = output.querySelector(scrollLists);
      var top = old ? old.scrollTop : 0;
      var applied = isVocab ? appliedVocab : null;
      if (isVocab) appliedVocab = null;
      setTimeout(function () {
        var list = output.querySelector(scrollLists);
        if (list) list.scrollTop = top;
        if (!isVocab) return;
        $('.preview-vocab-item').each(function () {
          var v = pickedVocab[$(this).data('key')];
          var sel = $(this).find('select')[0];
          if (!sel || v === undefined) return;
          sel.value = v;
          $(this).find('.preview-vocab-apply').prop('disabled', !sel.value);
        });
        if (list && applied !== null) revealNextVocab(list, applied);
      }, 0);
    });

    // The record can be taller than its panel. The marked column of the
    // problem then scrolls into the panel.
    $(document).on('shiny:value', function (e) {
      if (e.name !== cfg.recordId) return;
      var output = e.target;
      setTimeout(function () {
        var panel = output.querySelector('.preview-record');
        var mark = panel && panel.querySelector('.preview-record-key.is-problem');
        if (!mark) return;
        var p = panel.getBoundingClientRect();
        var m = mark.getBoundingClientRect();
        if (m.top >= p.top && m.bottom <= p.bottom) return;
        panel.scrollTop += m.top - p.top - (panel.clientHeight - m.height) / 2;
      }, 0);
    });

    // Exact copies: one row, or "all", in or out of the package.
    $(document).on('click', '.preview-copy-set', function (e) {
      e.preventDefault();
      Shiny.setInputValue(cfg.copyId, { row: this.dataset.row, out: this.dataset.out === '1' },
        { priority: 'event' });
    });

    // DT row selection toggles on each click, which closed the record panel
    // between the two clicks of an edit. A focus that only moves replaces
    // it, and one click on the Correction opens the editor.
    $(document).on('click', '.preview-rows-table tbody tr', function () {
      var dt = $(this).closest('table').DataTable();
      var d = dt.row(this).data();
      if (!d) return;
      $(dt.table().node()).data('pfFocus', rowKey(d));
      $(this).addClass('pf-focus').siblings().removeClass('pf-focus');
      Shiny.setInputValue(cfg.focusId, { row: d[0], term: d[1] });
    });
    $(document).on('click', '.preview-rows-table td.pf-fix-cell', function () {
      if (!$(this).find('input').length) $(this).trigger('dblclick');
    });

    // After a save the server names the next open problem. The handler waits
    // for the redraw of the save, scrolls only when that row is out of view,
    // and gives it the focus.
    Shiny.addCustomMessageHandler(cfg.fixNextChannel, function (m) {
      var table = $('#' + cfg.tableId + ' .dataTables_scrollBody table');
      if (!table.length) return;
      table.one('draw.dt', function () {
        var dt = table.DataTable();
        var key = m.row + '|' + m.term;
        table.data('pfFocus', key);
        dt.rows().every(function () {
          $(this.node()).toggleClass('pf-focus', rowKey(this.data()) === key);
        });
        var page = dt.scroller.page();
        if (m.pos < page.start || m.pos >= page.end) {
          dt.scroller.toPosition(Math.max(m.pos - 1, 0));
        }
        Shiny.setInputValue(cfg.focusId, { row: m.row, term: m.term });
      });
    });

    // DT commits a single-cell edit only on blur, so Enter blurs.
    $(document).on('keydown', '.preview-rows-table td input', function (e) {
      if (e.key === 'Enter') {
        e.preventDefault();
        this.blur();
      }
    });

    // Table | Problems shows content that is already there (ADR-158).
    // A conditionalPanel would make Shiny check every output.
    $(document).on('change', '#' + cfg.modeId, function () {
      var mode = $(this).find('input:checked').val();
      $('#' + cfg.contentId + ' [data-mode]').each(function () {
        this.classList.toggle('is-off', this.getAttribute('data-mode') !== mode);
      });
    });
  };

  // Table view: a long value is cut at 80 characters, with the full value
  // in the tooltip.
  behavior.previewTruncateCell = function () {
    return function (data, type) {
      if (data === null || data === undefined) return data;
      if (type !== 'display') return data;
      var text = String(data);
      var escaped = escapeHtml(text);
      if (text.length > 80) {
        return '<span title="' + escaped + '">' + escapeHtml(text.substr(0, 80)) + '...</span>';
      }
      return escaped;
    };
  };

  behavior.previewMarkEmptyColumns = function (cfg) {
    return function () {
      var emptyCols = cfg.emptyColumns;
      if (!Array.isArray(emptyCols) || emptyCols.length === 0) return;
      var api = this.api();
      api.columns().every(function (idx) {
        if (emptyCols.indexOf(idx) !== -1) {
          $(api.column(idx).header()).addClass('preview-col-empty');
        }
      });
    };
  };

  // Problems mode, Correction column. The row slots are set by the server:
  // 1 term, 5 actions HTML, 6 suggestion, 7 automatic value.
  behavior.previewFixValueCell = function (cfg) {
    var esc = escapeHtml;
    return function (data, type, row) {
      if (type !== 'display') return data;
      if (data) return '<span class="pf-done">' + esc(data) + '</span>';
      if (row[5].indexOf('preview-fix-undo') >= 0) {
        return '<span class="pf-done">' + cfg.emptyValue + '</span>';
      }
      if (row[7]) {
        return '<span class="pf-auto" title="' + esc(row[7]) + '">' + esc(row[7]) +
          '</span> <span class="pf-tag pf-tag-auto">' + cfg.auto + '</span>';
      }
      if (row[6]) {
        return '<span class="pf-ghost">' + esc(row[6]) + '</span> <span class="pf-tag">' +
          cfg.suggestion + '</span>';
      }
      var placeholder = row[1] === 'scientificName' ? cfg.placeholderTaxon : cfg.placeholder;
      return '<span class="pf-empty">' + placeholder + '</span>';
    };
  };

  // A redraw recreates the rows, so the focus class is put back from the
  // key kept on the table node.
  behavior.previewFocusRow = function () {
    return function () {
      var key = $(this.api().table().node()).data('pfFocus');
      this.api().rows().every(function () {
        $(this.node()).toggleClass('pf-focus', rowKey(this.data()) === key);
      });
    };
  };

  behavior.previewCutCell = function () {
    return function (data, type) {
      return type === 'display' ? '<span class="pf-cut">' + data + '</span>' : data;
    };
  };
})();

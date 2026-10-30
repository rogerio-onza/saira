// Wiki table behavior: term rows, header and the custom filters (ADR-170
// moved it out of mod_wiki.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  function text(value) {
    return String(value === null || value === undefined ? '' : value);
  }

  function escapeHtml(value) {
    return text(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function isTrue(value) {
    var normalized = text(value).trim().toLowerCase();
    return value === true || value === 1 || normalized === 'true' || normalized === '1' ||
      normalized === 'yes' || normalized === 'sim';
  }

  var REQUIRED_ICON = "<svg width='9' height='9' viewBox='0 0 24 24' fill='none' " +
    "stroke='currentColor' stroke-width='3'><polyline points='20 6 9 17 4 12'/></svg>";

  var SORT_ICON = "<svg class='wiki-sort-icon' width='12' height='12' viewBox='0 0 24 24' " +
    "fill='none' stroke='currentColor' stroke-width='2.5'><path d='m7 15 5 5 5-5'></path>" +
    "<path d='m7 9 5-5 5 5'></path></svg>";

  // Columns: 0 term, 1 class, 2 definition, 3 required.
  behavior.wikiTermRow = function (cfg) {
    return function (row, data) {
      var termText = text(data[0]);
      var classText = text(data[1]);
      var isRequired = isTrue(data[3]);
      var classSlug = cfg.classSlugs[classText.trim().toLowerCase()] || 'record-level';
      $('td:eq(0)', row).html("<a class='wiki-term-link' href='" + cfg.termUrl +
        "' target='_blank' rel='noopener noreferrer'>" + escapeHtml(termText) + "</a>");
      $('td:eq(1)', row).html("<span class='wiki-class-badge wiki-class-badge--" + classSlug + "'>" +
        escapeHtml(classText) + "</span>");
      $('td:eq(2)', row).text(text(data[2])).toggleClass('is-required', isRequired);
      var badge = isRequired ?
        "<span class='wiki-required-badge wiki-required-badge--true'>" + REQUIRED_ICON +
          escapeHtml(cfg.labels.required) + "</span>" :
        "<span class='wiki-required-badge wiki-required-badge--false'>" +
          escapeHtml(cfg.labels.optional) + "</span>";
      $('td:eq(3)', row).html(badge).addClass('wiki-required-cell');
    };
  };

  // DT callback: the search box, class pills or select, and page length
  // drive the table. The event namespace makes a new render replace the old
  // handlers.
  behavior.wikiTableFilters = function (cfg, table) {
    var searchSelector = '#' + cfg.searchId;
    var classSelector = '#' + cfg.classId;
    var pageSelector = '#' + cfg.pageId;
    var pillsSelector = '.wiki-filter-pill';
    var eventNs = '.wikiFilter.' + cfg.searchId.replace(/[^a-zA-Z0-9_-]/g, '');
    var $doc = $(document);

    var findModule = function () {
      var selectors = [searchSelector, classSelector, pageSelector];
      for (var i = 0; i < selectors.length; i++) {
        var $candidate = $(selectors[i]).closest('.wiki-module');
        if ($candidate.length) return $candidate;
      }
      return $(table.table().container()).closest('.wiki-module');
    };
    var $module = findModule();
    var getPills = function () {
      return $module.length ? $module.find(pillsSelector) : $(pillsSelector);
    };
    var setActivePill = function (filterValue) {
      var value = String(filterValue || '');
      var $pills = getPills();
      if (!$pills.length) return;
      $pills.removeClass('active').attr('aria-pressed', 'false');
      var $target = $pills.filter(function () {
        return String($(this).attr('data-filter') || '') === value;
      });
      if ($target.length === 0) $target = $pills.filter('[data-filter=""]');
      $target.addClass('active').attr('aria-pressed', 'true');
    };
    var applyClassFilter = function (filterValue, syncSelect) {
      var value = String(filterValue || '');
      table.column(1).search(value).draw(false);
      setActivePill(value);
      if (!syncSelect) return;
      var $classFilter = $(classSelector);
      if ($classFilter.length && String($classFilter.val() || '') !== value) {
        $classFilter.val(value);
      }
    };
    var applyGlobalSearch = function () {
      table.search(String(this.value || '')).draw(false);
    };

    $doc.off('input' + eventNs, searchSelector);
    $doc.off('keyup' + eventNs, searchSelector);
    $doc.off('search' + eventNs, searchSelector);
    $doc.off('change' + eventNs, classSelector);
    $doc.off('change' + eventNs, pageSelector);
    $doc.off('click' + eventNs, pillsSelector);

    $doc.on('input' + eventNs, searchSelector, applyGlobalSearch);
    $doc.on('keyup' + eventNs, searchSelector, applyGlobalSearch);
    $doc.on('search' + eventNs, searchSelector, applyGlobalSearch);
    $doc.on('change' + eventNs, classSelector, function () {
      applyClassFilter($(this).val() || '', false);
    });
    $doc.on('click' + eventNs, pillsSelector, function () {
      if ($module.length && $(this).closest('.wiki-module')[0] !== $module[0]) return;
      applyClassFilter($(this).attr('data-filter') || '', true);
    });
    $doc.on('change' + eventNs, pageSelector, function () {
      var len = parseInt($(this).val(), 10);
      if (!isNaN(len) && len > 0) table.page.len(len).draw(false);
    });
    table.off('length.dt' + eventNs).on('length.dt' + eventNs, function (e, settings, len) {
      var $pageLength = $(pageSelector);
      if ($pageLength.length) $pageLength.val(String(len));
    });

    var $searchInput = $(searchSelector);
    if ($searchInput.length) table.search($searchInput.val() || '');
    var $classFilter = $(classSelector);
    applyClassFilter($classFilter.length ? $classFilter.val() || '' : '', false);
    var $pageLength = $(pageSelector);
    if ($pageLength.length) {
      var selectedLen = parseInt($pageLength.val(), 10);
      if (!isNaN(selectedLen)) table.page.len(selectedLen);
      $pageLength.val(String(table.page.len()));
    }
    table.draw(false);
  };

  behavior.wikiTableHeader = function () {
    return function (thead) {
      $(thead).find('th').each(function (index) {
        var $th = $(this);
        if ($th.find('.wiki-th-content').length > 0) return;
        var label = $th.text();
        var centerClass = index === 3 ? ' wiki-th-content--center' : '';
        $th.html("<div class='wiki-th-content" + centerClass + "'><span class='wiki-th-label'>" +
          label + "</span>" + SORT_ICON + "</div>");
      });
    };
  };
})();

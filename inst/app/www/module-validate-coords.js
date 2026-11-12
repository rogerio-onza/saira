// Coordinates page behavior (ADR-170 moved it out of mod_validate_coords.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  // The undo links render per row, so one delegated handler serves every
  // row (same pattern as the names review links).
  behavior.coordsEditUndo = function (cfg) {
    $(document).on('click', '.coords-edit-undo', function (e) {
      e.preventDefault();
      Shiny.setInputValue(cfg.undoId, parseInt(this.dataset.row, 10), { priority: 'event' });
    });
  };

  // "Show in table" in a map popup sends the row to the server, which pages
  // the table to it. A capture listener: Leaflet stops click propagation out
  // of popups.
  behavior.coordsShowRow = function (cfg) {
    document.addEventListener('click', function (e) {
      var btn = e.target.closest && e.target.closest('.coords-show-row');
      if (!btn) return;
      e.preventDefault();
      // The page length lives in the browser, so it goes with the row.
      var tbl = $('#' + cfg.tableId + ' .dataTables_scrollBody table')[0] ||
        $('#' + cfg.tableId + ' table.dataTable')[0];
      var len = tbl && $.fn.dataTable.isDataTable(tbl) ? $(tbl).DataTable().page.len() : 10;
      Shiny.setInputValue(cfg.locateId, { row: parseInt(btn.dataset.row, 10), len: len },
        { priority: 'event' });
    }, true);
  };
})();

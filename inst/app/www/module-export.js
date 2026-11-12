// Export page behavior (ADR-170 moved it out of mod_export.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  // The summary renders again on each change, so only new tips get a tooltip.
  behavior.exportTooltips = function () {
    if (!window.bootstrap || !window.bootstrap.Tooltip) return;
    document.querySelectorAll('.export-info-tip[data-bs-toggle="tooltip"]').forEach(function (el) {
      if (el.__tipInit) return;
      el.__tipInit = true;
      new window.bootstrap.Tooltip(el);
    });
  };

  // The desktop shell reads this flag on close. "current" means that the data
  // did not change after the last bundle. One handler per page.
  behavior.exportBundleState = function () {
    if (window.__sairaBundleStateHandler || !window.Shiny) return;
    window.__sairaBundleStateHandler = true;
    Shiny.addCustomMessageHandler('saira-bundle-state', function (state) {
      document.documentElement.dataset.sairaBundle = state === 'current' ? 'current' : 'stale';
    });
  };

  // The count chips of the pending card show one severity. The card renders
  // again on each change, so one click handler on the page serves every copy.
  behavior.exportPendingFilter = function () {
    if (window.__sairaPendingFilterHandler) return;
    window.__sairaPendingFilterHandler = true;
    document.addEventListener('click', function (event) {
      var chip = event.target.closest('.export-pending-chip');
      if (!chip) return;
      var card = chip.closest('.export-pending');
      if (!card) return;
      card.dataset.filter = chip.dataset.filter;
      card.querySelectorAll('.export-pending-chip').forEach(function (el) {
        el.setAttribute('aria-pressed', el === chip ? 'true' : 'false');
      });
    });
  };

  // The "fix" link of the blocked banner opens Mapping and names a field
  // card. The card scrolls into view and flashes. One handler per page.
  behavior.exportFocusField = function () {
    if (window.__sairaFocusFieldHandler || !window.Shiny) return;
    window.__sairaFocusFieldHandler = true;
    Shiny.addCustomMessageHandler('saira_focus_field', function (msg) {
      if (!msg || !msg.id) return;
      setTimeout(function () {
        var el = document.getElementById(msg.id);
        if (!el) return;
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        el.classList.add('field-card-flash');
        setTimeout(function () {
          el.classList.remove('field-card-flash');
        }, 2200);
      }, 300);
    });
  };
})();

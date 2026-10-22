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

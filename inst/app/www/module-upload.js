// Upload mode tabs (ADR-170 moved it out of mod_upload.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  // A tab click checks the hidden radio of its mode, so Shiny sees a normal
  // radio change.
  behavior.uploadModeTabs = function () {
    if (window.__sairaUploadModeTabsWired) return;
    window.__sairaUploadModeTabsWired = true;
    document.addEventListener('click', function (e) {
      var tab = e.target.closest && e.target.closest('.upload-mode-tab');
      if (!tab) return;
      e.preventDefault();
      var wrap = tab.closest('.upload-mode-tabs');
      if (!wrap) return;
      var mode = tab.getAttribute('data-mode');
      var radio = wrap.querySelector('input[type="radio"][value="' + mode + '"]');
      if (!radio || radio.checked) return;
      radio.checked = true;
      radio.dispatchEvent(new Event('change', { bubbles: true }));
      radio.focus({ preventScroll: true });
    });
  };
})();

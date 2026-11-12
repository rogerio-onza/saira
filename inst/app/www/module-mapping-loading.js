// Auto-map loading modal: phrases rotate and the bar creeps to 92% until the
// server closes the modal (ADR-170 moved it out of mod_mapping_loading.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  var FADE_MS = 280;
  var STEP_MS = 2500;

  behavior.mappingLoadingModal = function (cfg) {
    var iconEl = document.getElementById(cfg.iconId);
    var textEl = document.getElementById(cfg.textId);
    var rowEl = document.getElementById(cfg.rowId);
    var poolRoot = document.getElementById(cfg.poolId);
    var progressEl = document.getElementById(cfg.progressId);
    var statusEl = document.getElementById(cfg.statusId);
    if (!iconEl || !textEl || !rowEl || !poolRoot) return;
    var items = poolRoot.querySelectorAll('.automap-loading-phrase-item');
    if (!items.length) return;

    var timerKey = cfg.timerKey;
    var timeoutKey = timerKey + '_fade';
    var progressKey = timerKey + '_progress';
    var modalEl = poolRoot.closest('.modal');
    var progressValue = cfg.progress;

    var clearTimers = function () {
      if (window[timerKey]) window.clearInterval(window[timerKey]);
      if (window[timeoutKey]) window.clearTimeout(window[timeoutKey]);
      if (window[progressKey]) window.clearInterval(window[progressKey]);
      window[timerKey] = window[timeoutKey] = window[progressKey] = null;
    };
    var applyProgress = function (value) {
      var pct = Math.max(0, Math.min(100, Math.round(value)));
      if (progressEl) progressEl.style.width = pct + '%';
      if (statusEl) {
        statusEl.textContent = cfg.statusPrefix ? cfg.statusPrefix + ' ' + pct + '%' : pct + '%';
      }
    };
    var applyPhrase = function (index) {
      var item = items[index];
      if (!item) return;
      var nextIcon = item.getAttribute('data-icon') || 'gear-six';
      iconEl.className = 'ph ph-' + nextIcon + ' automap-loading-phrase-icon';
      textEl.textContent = item.textContent || '';
    };

    if (modalEl) modalEl.classList.add('automap-loading-host');
    if (document.body) document.body.classList.add('automap-loading-open');
    clearTimers();

    var idx = 0;
    applyPhrase(idx);
    applyProgress(progressValue);
    window[timerKey] = window.setInterval(function () {
      rowEl.classList.add('is-fading');
      window[timeoutKey] = window.setTimeout(function () {
        idx = (idx + 1) % items.length;
        applyPhrase(idx);
        rowEl.classList.remove('is-fading');
        window[timeoutKey] = null;
      }, FADE_MS);
    }, STEP_MS);
    window[progressKey] = window.setInterval(function () {
      if (progressValue < 92) {
        progressValue += 1;
        applyProgress(progressValue);
      }
    }, 240);

    var clearState = function () {
      clearTimers();
      if (modalEl) modalEl.classList.remove('automap-loading-host');
      if (document.body) document.body.classList.remove('automap-loading-open');
    };
    (modalEl || document).addEventListener('hidden.bs.modal', clearState, { once: true });
  };
})();

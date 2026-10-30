// Export download: the hidden download button and the loading modal
// (ADR-170 moved them out of mod_export_download.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  function clearTimer(key) {
    if (key && window[key]) {
      window.clearInterval(window[key]);
      window[key] = null;
    }
  }

  function hideModal(modalEl) {
    if (!modalEl) return;
    var instance = window.bootstrap && window.bootstrap.Modal &&
      window.bootstrap.Modal.getInstance(modalEl);
    if (instance) {
      instance.hide();
    } else if (window.jQuery) {
      window.jQuery(modalEl).modal('hide');
    }
  }

  // The renderUI runs again on each state change, so the handlers register
  // once per channel.
  behavior.exportDownloadHandlers = function (cfg) {
    window.__sairaPreviewDownloadHandlers = window.__sairaPreviewDownloadHandlers || {};
    if (window.__sairaPreviewDownloadHandlers[cfg.clickChannel]) return;
    window.__sairaPreviewDownloadHandlers[cfg.clickChannel] = true;

    Shiny.addCustomMessageHandler(cfg.clickChannel, function (payload) {
      var btn = document.getElementById(payload.id);
      if (btn) btn.click();
    });

    Shiny.addCustomMessageHandler(cfg.finishChannel, function (payload) {
      var byId = function (id) {
        return id ? document.getElementById(id) : null;
      };
      var progressEl = byId(payload.progress_id);
      var statusEl = byId(payload.status_id);
      var phraseIconEl = byId(payload.phrase_icon_id);
      var phraseTextEl = byId(payload.phrase_text_id);
      var poolRoot = byId(payload.modal_root_id);
      var timerKey = payload.timer_key || null;

      clearTimer(timerKey);
      clearTimer(timerKey ? timerKey + '_progress' : null);
      if (progressEl) progressEl.style.width = '100%';
      if (statusEl && payload.status_text) statusEl.textContent = payload.status_text;
      if (phraseIconEl && payload.final_icon) {
        phraseIconEl.className = 'ph ph-' + payload.final_icon + ' automap-loading-phrase-icon';
      }
      if (phraseTextEl && payload.final_phrase) phraseTextEl.textContent = payload.final_phrase;

      var modalEl = poolRoot ? poolRoot.closest('.modal') : null;
      window.setTimeout(function () {
        hideModal(modalEl);
      }, payload.delay_ms || 320);
    });
  };

  // The bar moves 10% every 900 ms up to 90%. The finish message fills it.
  behavior.exportProgressModal = function (cfg) {
    var iconEl = document.getElementById(cfg.iconId);
    var textEl = document.getElementById(cfg.textId);
    var poolRoot = document.getElementById(cfg.poolId);
    var progressEl = document.getElementById(cfg.progressId);
    var statusEl = document.getElementById(cfg.statusId);
    if (!iconEl || !textEl || !poolRoot || !progressEl || !statusEl) return;
    var items = poolRoot.querySelectorAll('.automap-loading-phrase-item');
    if (!items.length) return;

    var timerKey = cfg.timerKey;
    var progressKey = timerKey + '_progress';
    var modalEl = poolRoot.closest('.modal');
    var progressValue = 0;

    var applyProgress = function (value) {
      var pct = Math.max(0, Math.min(100, Math.round(value)));
      progressEl.style.width = pct + '%';
      statusEl.textContent = cfg.statusPrefix ? cfg.statusPrefix + ' ' + pct + '%' : pct + '%';
    };
    var applyPhrase = function (index) {
      var item = items[index];
      if (!item) return;
      var nextIcon = item.getAttribute('data-icon') || 'gear-six';
      iconEl.className = 'ph ph-' + nextIcon + ' automap-loading-phrase-icon';
      textEl.textContent = item.textContent || '';
    };

    clearTimer(timerKey);
    clearTimer(progressKey);
    applyPhrase(0);
    applyProgress(0);
    window[progressKey] = window.setInterval(function () {
      if (progressValue < 90) {
        progressValue += 10;
        applyProgress(progressValue);
        applyPhrase(Math.min(items.length - 1, Math.max(0, Math.floor(progressValue / 10) - 1)));
      }
    }, 900);
    if (modalEl) modalEl.classList.add('automap-loading-host');
    if (document.body) document.body.classList.add('automap-loading-open');

    var clearState = function () {
      clearTimer(timerKey);
      clearTimer(progressKey);
      if (modalEl) modalEl.classList.remove('automap-loading-host');
      if (document.body) document.body.classList.remove('automap-loading-open');
    };
    (modalEl || document).addEventListener('hidden.bs.modal', clearState, { once: true });
  };
})();

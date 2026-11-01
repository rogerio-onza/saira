// Behavior factories (ADR-170). R renders only a call with a JSON
// configuration, so IDs and translated text never become code.
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  // Keep <html lang> in step with the language selector, so screen readers
  // and the browser hyphenation follow the interface.
  behavior.syncHtmlLang = function () {
    var tags = { pt: 'pt-BR', en: 'en', es: 'es' };
    $(document).on('shiny:inputchanged', function (e) {
      if (e.name !== 'lang_switch') return;
      document.documentElement.lang = tags[e.value] || e.value;
    });
  };
})();

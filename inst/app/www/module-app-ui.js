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

  // Three patches for every selectize in the app (ADR-198).
  // 1. selectize marks its search field autocomplete="new-password", so a
  //    password manager treats each column picker as a new password field.
  //    Bitwarden opened its own menu over the column list and slowed the page.
  // 2. A dropdown that a scroll box cuts at the bottom opens above the field.
  // 3. While a dropdown is open, the toasts give way (CSS in 06-alerts.css).
  var AUTOFILL_OFF = {
    autocomplete: 'off',
    'data-bwignore': 'true',
    'data-1p-ignore': 'true',
    'data-lpignore': 'true',
    'data-form-type': 'other'
  };
  window.sairaAutofillOff = AUTOFILL_OFF;

  // The nearest ancestor that cuts its content, as a rectangle in the view.
  function clipRect(el) {
    for (var p = el.parentElement; p && p !== document.body; p = p.parentElement) {
      var oy = window.getComputedStyle(p).overflowY;
      if (oy !== 'visible') return p.getBoundingClientRect();
    }
    return null;
  }

  function placeDropdown(self) {
    if (self.settings.dropdownParent === 'body') return;
    var dd = self.$dropdown[0];
    // A bottom left from the last call, with the new top, squeezes the
    // height to zero, so clear it before the measure.
    dd.style.bottom = '';
    var height = dd.offsetHeight;
    var c = self.$control[0].getBoundingClientRect();
    var box = clipRect(self.$wrapper[0]);
    var top = Math.max(0, box ? box.top : 0);
    var bottom = Math.min(window.innerHeight, box ? box.bottom : window.innerHeight);
    var below = bottom - c.bottom;
    var up = height > below && c.top - top > below;
    self.$dropdown.toggleClass('selectize-position-top', up);
    self.$control.toggleClass('selectize-position-top', up);
    // bottom, not top: a filter that shortens the list keeps it on the field.
    if (up) {
      dd.style.top = 'auto';
      dd.style.bottom = '100%';
    }
  }

  function patchSelectize() {
    var proto = window.Selectize && window.Selectize.prototype;
    if (!proto || proto.sairaPatched) return;
    proto.sairaPatched = true;
    var setup = proto.setup;
    var position = proto.positionDropdown;
    var open = proto.open;
    var close = proto.close;
    proto.setup = function () {
      setup.apply(this, arguments);
      this.$control_input.attr(AUTOFILL_OFF);
    };
    proto.positionDropdown = function () {
      position.apply(this, arguments);
      placeDropdown(this);
    };
    proto.open = function () {
      open.apply(this, arguments);
      if (this.isOpen) document.documentElement.classList.add('saira-select-open');
    };
    proto.close = function () {
      close.apply(this, arguments);
      document.documentElement.classList.remove('saira-select-open');
    };
  }

  // The selectize library comes with the first select that a renderUI
  // sends, so the patch waits for the binding that creates each selectize.
  // Shiny 1.14 keeps no name in getBindings(), so look for the method.
  var selectBinding = window.Shiny && Shiny.inputBindings &&
    Shiny.inputBindings.getBindings().filter(function (b) {
      return typeof b.binding._selectize === 'function';
    })[0];
  if (selectBinding && !selectBinding.binding.sairaHooked) {
    var binding = selectBinding.binding;
    var create = binding._selectize;
    binding.sairaHooked = true;
    binding._selectize = function () {
      patchSelectize();
      return create.apply(this, arguments);
    };
  }
})();

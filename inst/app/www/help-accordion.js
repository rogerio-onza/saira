(function () {
  if (window.__finchHelpAccordionBound) {
    return;
  }
  window.__finchHelpAccordionBound = true;

  function getAccordion(target) {
    return target.closest("[data-help-accordion='true']");
  }

  function getItem(target) {
    return target.closest("[data-help-acc-item='true']");
  }

  function setItemState(item, open) {
    if (!item) {
      return;
    }

    item.classList.toggle("is-open", open);

    var button = item.querySelector("[data-help-acc-toggle='true']");
    if (button) {
      button.setAttribute("aria-expanded", open ? "true" : "false");
    }

    var body = item.querySelector("[data-help-acc-body='true']");
    if (body) {
      body.setAttribute("aria-hidden", open ? "false" : "true");
    }
  }

  function openExclusive(item) {
    var accordion = getAccordion(item);
    if (!accordion) {
      return;
    }

    var items = accordion.querySelectorAll("[data-help-acc-item='true']");
    items.forEach(function (candidate) {
      setItemState(candidate, candidate === item);
    });
  }

  function onToggleClick(event) {
    var toggle = event.target.closest("[data-help-acc-toggle='true']");
    if (!toggle) {
      return;
    }

    var item = getItem(toggle);
    if (!item) {
      return;
    }

    var isOpen = item.classList.contains("is-open");
    if (isOpen) {
      setItemState(item, false);
      return;
    }

    openExclusive(item);
  }

  document.addEventListener("click", onToggleClick, false);
})();

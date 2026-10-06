// Theme switch: light, dark or follow the system (ADR-144).
// An inline script in <head> paints the stored theme before the first frame.
// This file runs the segmented control in the navbar and the circle reveal.
(function () {
  "use strict";

  var KEY = "saira-theme";
  var root = document.documentElement;
  var media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  function storedMode() {
    try {
      var m = window.localStorage.getItem(KEY);
      return m === "light" || m === "dark" ? m : "system";
    } catch (e) {
      return "system";
    }
  }

  function storeMode(mode) {
    try {
      if (mode === "system") window.localStorage.removeItem(KEY);
      else window.localStorage.setItem(KEY, mode);
    } catch (e) { /* private window: the choice lasts for this page only */ }
  }

  function resolve(mode) {
    if (mode !== "system") return mode;
    return media && media.matches ? "dark" : "light";
  }

  // Light removes the attribute, so the light page is the same as before the
  // dark theme existed.
  function paint(theme) {
    if (theme === "dark") root.setAttribute("data-bs-theme", "dark");
    else root.removeAttribute("data-bs-theme");
  }

  function current() {
    return root.getAttribute("data-bs-theme") === "dark" ? "dark" : "light";
  }

  function buttons() {
    return document.querySelectorAll(".theme-switch button[data-theme]");
  }

  function markPressed(mode) {
    Array.prototype.forEach.call(buttons(), function (b) {
      b.setAttribute("aria-pressed", b.getAttribute("data-theme") === mode ? "true" : "false");
    });
  }

  function reducedMotion() {
    return !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  }

  // The new theme grows as a circle from (x, y) over the old one.
  function apply(theme, x, y) {
    if (theme === current()) return;
    if (!document.startViewTransition || reducedMotion()) {
      paint(theme);
      return;
    }
    var r = Math.hypot(Math.max(x, window.innerWidth - x), Math.max(y, window.innerHeight - y));
    root.classList.add("theme-reveal");
    var vt = document.startViewTransition(function () { paint(theme); });
    vt.ready.then(function () {
      root.animate(
        { clipPath: ["circle(0px at " + x + "px " + y + "px)", "circle(" + r + "px at " + x + "px " + y + "px)"] },
        { duration: 600, easing: "cubic-bezier(.4,0,.2,1)", pseudoElement: "::view-transition-new(root)" }
      );
    }).catch(function () {});
    vt.finished.finally(function () { root.classList.remove("theme-reveal"); });
  }

  function centerOf(el) {
    if (!el) return { x: window.innerWidth - 1, y: 0 };
    var box = el.getBoundingClientRect();
    return { x: box.left + box.width / 2, y: box.top + box.height / 2 };
  }

  document.addEventListener("click", function (e) {
    var btn = e.target.closest ? e.target.closest(".theme-switch button[data-theme]") : null;
    if (!btn) return;
    var mode = btn.getAttribute("data-theme");
    storeMode(mode);
    markPressed(mode);
    var c = centerOf(btn);
    apply(resolve(mode), c.x, c.y);
  });

  if (media) {
    var onSystemChange = function () {
      if (storedMode() !== "system") return;
      var c = centerOf(document.querySelector('.theme-switch button[data-theme="system"]'));
      apply(resolve("system"), c.x, c.y);
    };
    if (media.addEventListener) media.addEventListener("change", onSystemChange);
    else if (media.addListener) media.addListener(onSystemChange);
  }

  // The labels follow the language selector. Shiny fires this as a jQuery
  // event, not a DOM event.
  if (window.jQuery) {
    window.jQuery(document).on("shiny:inputchanged", function (e) {
      if (e.name !== "lang_switch") return;
      var attr = "data-label-" + e.value;
      var nodes = document.querySelectorAll(".theme-switch, .theme-switch button[data-theme]");
      Array.prototype.forEach.call(nodes, function (n) {
        var label = n.getAttribute(attr);
        if (!label) return;
        n.setAttribute("aria-label", label);
        n.setAttribute("title", label);
      });
    });
  }

  function init() { markPressed(storedMode()); }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

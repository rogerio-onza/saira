// Tab motion (ADR-145): the page slides 32 px in the direction of the step.
// The View Transitions API animates snapshots, so Shiny and the widgets see a
// plain tab change. 20-motion.css has the keyframes and the fallback for a
// browser without the API.
(function () {
  "use strict";

  var root = document.documentElement;
  var replaying = false;

  function mainNav() {
    return document.getElementById("main_nav");
  }

  function tabIndex(link) {
    var nav = mainNav();
    if (!nav || !link) return -1;
    var links = nav.querySelectorAll('.nav-link[data-bs-toggle="tab"]');
    return Array.prototype.indexOf.call(links, link);
  }

  function reducedMotion() {
    return !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  }

  function showTab(link) {
    if (window.bootstrap && window.bootstrap.Tab) window.bootstrap.Tab.getOrCreateInstance(link).show();
    else if (window.jQuery) window.jQuery(link).tab("show");
  }

  // Bootstrap fires this before it changes the tab, for a click and for a
  // tab change from the server. Cancel it, then show the same tab again
  // inside a view transition.
  var pending = null;
  var latest = 0;
  document.addEventListener("show.bs.tab", function (e) {
    if (replaying || !document.startViewTransition || reducedMotion()) return;
    var link = e.target;
    var nav = mainNav();
    if (!nav || !nav.contains(link)) return;

    e.preventDefault();
    // One click fires this twice. The second call must not start a new
    // transition: that skips the first one.
    if (link === pending) return;
    pending = link;

    var back = tabIndex(link) < tabIndex(e.relatedTarget);
    var id = ++latest;
    root.classList.add("vt-tab");
    root.classList.toggle("vt-back", back);
    var vt = document.startViewTransition(function () {
      pending = null;
      replaying = true;
      try { showTab(link); } finally { replaying = false; }
    });
    vt.finished.finally(function () {
      if (id === latest) root.classList.remove("vt-tab", "vt-back");
    });
  });

  // Mark the page area of the main navbar. Inner tab sets keep their
  // own behavior.
  function init() {
    var nav = mainNav();
    var id = nav && nav.getAttribute("data-tabsetid");
    var pages = id && document.querySelector('.tab-content[data-tabsetid="' + id + '"]');
    if (pages) pages.classList.add("saira-pages");
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

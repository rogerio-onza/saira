// Tab motion (ADR-145): the page slides 32 px in the direction of the step.
// The View Transitions API animates snapshots, so Shiny and the widgets see a
// plain tab change. 20-motion.css has the keyframes and the fallback for a
// browser without the API. The segmented filters (ADR-156) are at the end.
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

  // Segmented filters (ADR-156): one thumb slides to the picked option of a
  // .saira-seg control. After a pick by the user, the element named in
  // data-seg-target comes in 32 px from the side of the option, as a page
  // does on a step change. data-seg-wait names an output in that element
  // that the server renders again. The old content dims until the new
  // content of that output arrives.
  var $ = window.jQuery;
  if (!$) return;

  var groups = [];
  var resizeObs = window.ResizeObserver ? new ResizeObserver(function (entries) {
    entries.forEach(function (entry) { placeThumb(entry.target, true); });
  }) : null;

  function checkedIndex(group) {
    var radios = group.querySelectorAll('input[type="radio"]');
    for (var i = 0; i < radios.length; i++) if (radios[i].checked) return i;
    return -1;
  }

  // A hidden tab gives the options no size. The thumb then moves without a
  // transition when the control shows again.
  function placeThumb(group, animate) {
    var thumb = group.querySelector(".seg-thumb");
    var input = group.querySelector('input[type="radio"]:checked');
    var label = input && input.closest("label");
    group.segIndex = checkedIndex(group);
    if (!thumb || !label || !label.offsetWidth) {
      group.segPlaced = false;
      return;
    }
    var instant = !animate || !group.segPlaced;
    if (instant) thumb.style.transition = "none";
    thumb.style.width = label.offsetWidth + "px";
    thumb.style.height = label.offsetHeight + "px";
    thumb.style.transform = "translate(" + label.offsetLeft + "px, " + label.offsetTop + "px)";
    if (instant) {
      void thumb.offsetWidth;
      thumb.style.transition = "";
    }
    group.segPlaced = true;
    group.closest(".saira-seg").classList.add("has-thumb");
  }

  // renderUI replaces a control on a language change, so look for new
  // controls after each output value.
  function initSegs() {
    groups = groups.filter(function (group) {
      if (group.isConnected) return true;
      if (resizeObs) resizeObs.unobserve(group);
      return false;
    });
    document.querySelectorAll(".saira-seg .shiny-options-group").forEach(function (group) {
      if (group.querySelector(".seg-thumb")) return;
      var thumb = document.createElement("span");
      thumb.className = "seg-thumb";
      thumb.setAttribute("aria-hidden", "true");
      group.prepend(thumb);
      placeThumb(group, false);
      groups.push(group);
      if (resizeObs) resizeObs.observe(group);
    });
  }

  var initQueued = false;
  $(document).on("shiny:value", function () {
    if (initQueued) return;
    initQueued = true;
    window.setTimeout(function () {
      initQueued = false;
      initSegs();
    }, 0);
  });

  function enter(el, back) {
    el.classList.remove("seg-enter");
    void el.offsetWidth;
    el.classList.toggle("seg-back", back);
    el.classList.add("seg-enter");
  }

  // The value event comes before the render, so the new content is in place
  // on the next task. The first frame of a large grid spends about 100 ms on
  // layout and paint, and a slide that starts in that frame loses its first
  // part. The box stays hidden for that frame, and the slide starts after it.
  function enterAfterRender(el, output, back) {
    el.classList.add("seg-wait");
    $(output).off(".segEnter").on("shiny:value.segEnter shiny:error.segEnter", function (e) {
      if (e.target !== output) return;
      $(output).off(".segEnter");
      window.setTimeout(function () {
        el.classList.replace("seg-wait", "seg-hold");
        window.requestAnimationFrame(function () {
          window.requestAnimationFrame(function () {
            el.classList.remove("seg-hold");
            enter(el, back);
          });
        });
      }, 0);
    });
  }

  // A pick by the user is a trusted event. An update from the server
  // moves the thumb only.
  $(document).on("change", ".saira-seg", function (e) {
    initSegs();
    var group = this.querySelector(".shiny-options-group");
    if (!group) return;
    var from = group.segIndex;
    placeThumb(group, true);
    var to = group.segIndex;
    var byUser = !!(e.originalEvent && e.originalEvent.isTrusted);
    if (!byUser || to === from || reducedMotion()) return;
    var target = document.getElementById(this.getAttribute("data-seg-target"));
    if (!target || !target.getClientRects().length) return;
    var output = document.getElementById(this.getAttribute("data-seg-wait"));
    if (output) enterAfterRender(target, output, to < from);
    else window.requestAnimationFrame(function () { enter(target, to < from); });
  });

  $(document).on("animationend animationcancel", ".seg-enter", function (e) {
    if (e.target === this) this.classList.remove("seg-enter", "seg-back");
  });
})();

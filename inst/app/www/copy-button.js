// Copy buttons (ADR-146): a button with data-copy puts that text on the
// clipboard, then shows data-done for a short time. The Help tab uses it for
// the citation.
(function () {
  "use strict";

  // The clipboard API needs a secure context. An app on a plain http server
  // gets the older copy command.
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.style.position = "fixed";
      area.style.opacity = "0";
      document.body.appendChild(area);
      area.select();
      var ok = false;
      try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
      document.body.removeChild(area);
      if (ok) resolve(); else reject(new Error("copy failed"));
    });
  }

  document.addEventListener("click", function (e) {
    var btn = e.target.closest ? e.target.closest("button[data-copy]") : null;
    if (!btn) return;
    var label = btn.querySelector(".copy-label");
    copyText(btn.getAttribute("data-copy")).then(function () {
      if (!label) return;
      // Keep the first label: a second click comes while "copied" shows.
      if (!btn.hasAttribute("data-label")) btn.setAttribute("data-label", label.textContent);
      label.textContent = btn.getAttribute("data-done") || label.textContent;
      btn.classList.add("is-done");
      clearTimeout(btn.copyTimer);
      btn.copyTimer = setTimeout(function () {
        label.textContent = btn.getAttribute("data-label");
        btn.classList.remove("is-done");
      }, 1600);
    }).catch(function () { /* the citation stays on screen to copy by hand */ });
  });
})();

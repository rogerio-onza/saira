// Landing page animations: the flow panel (spreadsheet, app tabs,
// occurrence.txt) and the install console. All visible text comes from the
// page markup, so the PT, EN and ES pages share this file.
(function () {
  "use strict";

  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Fictional camera-trap rows. Raw cells are [before, bad part, after].
  // `listed` rows are on the MMA list, so their coordinates are generalized.
  var ROWS = [
    { listed: true,
      raw: [["Leopardus ", "wiedi", ""], ["", "-51,82371", ""], ["", "-19,64183", ""], ["", "23/11/2023", ""], ["Fazenda S", "Ã£", "o Bento"]],
      name: "Leopardus wiedii", lat: "-19.64183", lon: "-51.82371", gLat: "-19.6", gLon: "-51.8",
      date: "2023-11-23", local: "Fazenda São Bento", cat: "VU" },
    { listed: false,
      raw: [["Puma concolor", "", ""], ["-19", ",", "70215"], ["-51", ",", "90433"], ["", "14/12/2023", ""], ["Fazenda S", "Ã£", "o Bento"]],
      name: "Puma concolor", lat: "-19.70215", lon: "-51.90433", date: "2023-12-14", local: "Fazenda São Bento" },
    { listed: true,
      raw: [["Herpailurus ", "yagouarundi", ""], ["-19", ",", "58831"], ["-51", ",", "77102"], ["", "19/10/2023", ""], ["Retiro Boa Esperan", "Ã§", "a"]],
      name: "Herpailurus yagouaroundi", lat: "-19.58831", lon: "-51.77102", gLat: "-19.6", gLon: "-51.8",
      date: "2023-10-19", local: "Retiro Boa Esperança", cat: "VU" },
    { listed: false,
      raw: [["Leopardus pardalis", "", ""], ["-19", ",", "61544"], ["-51", ",", "85391"], ["", "28/09/2023", ""], ["Retiro Boa Esperan", "Ã§", "a"]],
      name: "Leopardus pardalis", lat: "-19.61544", lon: "-51.85391", date: "2023-09-28", local: "Retiro Boa Esperança" }
  ];
  var TERMS = ["scientificName", "decimalLatitude", "decimalLongitude", "eventDate", "locality"];

  // Tab order matches the app navbar. A tab's result shows once the next tab
  // is active, so "from" is the tab index plus one.
  var HOME = 0, MAPPING = 1, PREVIEW = 2, NAMES = 3, COORDS = 4, GENERALIZE = 5, EXPORT = 6;
  // the tab that fixes each raw column: species, lat, long, date, locality
  var FIX_TAB = [NAMES, COORDS, COORDS, EXPORT, HOME];
  var HOLD = 3;
  var STEP_MS = 1800;

  function make(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text) node.textContent = text;
    return node;
  }

  function fill(cell, parts, badCls) {
    cell.textContent = "";
    if (parts[0]) cell.appendChild(document.createTextNode(parts[0]));
    if (parts[1]) cell.appendChild(make("span", badCls, parts[1]));
    if (parts[2]) cell.appendChild(document.createTextNode(parts[2]));
  }

  function initFlow(panel) {
    var tabs = [].slice.call(panel.querySelectorAll(".lp-tabs li"));
    var segs = [].slice.call(panel.querySelectorAll(".lp-segs span"));
    var verb = panel.querySelector(".lp-verb");
    var status = panel.querySelector(".lp-status");
    var toggle = panel.querySelector(".lp-toggle");
    var gridIn = panel.querySelector(".lp-in");
    var gridOut = panel.querySelector(".lp-out");
    var cols = gridIn.getAttribute("data-cols").split("|");
    var last = tabs.length + HOLD - 1;
    var lane = -1, playing = !reduce, visible = false, timer = null;

    function row(grid, label) {
      var r = make("div", "lp-row");
      r.setAttribute("role", "row");
      r.appendChild(make("span", "lp-num", label));
      grid.appendChild(r);
      return r;
    }
    function cell(r, header) {
      var c = make("span", "lp-cell");
      c.setAttribute("role", header ? "columnheader" : "cell");
      r.appendChild(c);
      return c;
    }

    // top sheet: built once, then only classes change
    var inCells = [];
    var head = row(gridIn, "1");
    var inHead = cols.map(function (name) { var c = cell(head, true); c.textContent = name; return c; });
    ROWS.forEach(function (data, r) {
      var line = row(gridIn, String(r + 2));
      inCells.push(data.raw.map(function (parts) { var c = cell(line, false); fill(c, parts, "lp-bad"); return c; }));
    });

    // bottom sheet: each cell lists its stages, the newest one with from <= lane shows
    var outCells = [];
    function addOut(r, header, stages, ph, ghost) {
      var c = cell(r, header);
      outCells.push({ node: c, stages: stages, ph: ph, ghost: ghost, shown: null });
    }
    var oh = row(gridOut, "1");
    cols.forEach(function (name, i) {
      addOut(oh, true, [{ from: MAPPING, parts: [name], cls: "lp-muted" }, { from: PREVIEW, parts: [TERMS[i]], pop: true }], 72);
    });
    addOut(oh, true, [{ from: PREVIEW, parts: ["dynamicProperties"], pop: true }], 0, true);
    ROWS.forEach(function (data, r) {
      var line = row(gridOut, String(r + 2));
      var raw = data.raw;
      var lat = [{ from: MAPPING, parts: raw[1] }, { from: COORDS + 1, parts: [data.lat], pop: true }];
      var lon = [{ from: MAPPING, parts: raw[2] }, { from: COORDS + 1, parts: [data.lon], pop: true }];
      if (data.listed) {
        lat.push({ from: GENERALIZE + 1, parts: [data.gLat], pop: true });
        lon.push({ from: GENERALIZE + 1, parts: [data.gLon], pop: true });
      }
      addOut(line, false, [{ from: MAPPING, parts: raw[0] }, { from: NAMES + 1, parts: [data.name], pop: true, cls: "lp-italic" }], 120);
      addOut(line, false, lat, 64);
      addOut(line, false, lon, 64);
      addOut(line, false, [{ from: MAPPING, parts: raw[3] }, { from: EXPORT + 1, parts: [data.date], pop: true }], 72);
      addOut(line, false, [{ from: MAPPING, parts: [data.local], pop: true }], 110);
      addOut(line, false, [{ from: EXPORT + 1, parts: [data.cat ? '{"mmaThreatStatus":"' + data.cat + '"}' : ""], pop: true }], 150, true);
    });

    function hotIn(r, c, L) {
      if (L === HOME) return r >= 0 && c === 4;
      if (L === MAPPING) return r < 0;
      if (L === NAMES) return r >= 0 && c === 0;
      if (L === COORDS) return r >= 0 && (c === 1 || c === 2);
      if (L === GENERALIZE) return r >= 0 && (c === 1 || c === 2) && ROWS[r].listed;
      if (L === EXPORT) return r >= 0 && c === 3;
      return false;
    }

    function render() {
      var L = lane;
      var moving = L >= 0 && L < tabs.length;
      var showDyn = L >= PREVIEW;

      inHead.forEach(function (c, i) { c.classList.toggle("is-hot", hotIn(-1, i, L)); });
      inCells.forEach(function (line, r) {
        line.forEach(function (c, i) {
          c.classList.toggle("is-hot", hotIn(r, i, L));
          var bad = c.querySelector(".lp-bad, .lp-struck");
          if (bad) bad.className = FIX_TAB[i] < L ? "lp-struck" : "lp-bad";
        });
      });

      outCells.forEach(function (o) {
        var k = -1;
        o.stages.forEach(function (s, i) { if (s.from <= L) k = i; });
        o.node.classList.toggle("is-ghost", !!o.ghost && !showDyn);
        o.node.classList.toggle("is-hot", L === PREVIEW);
        var key = k < 0 ? (o.ph && !(o.ghost && !showDyn) ? "ph" : "none") : k;
        if (key === o.shown) return;
        o.shown = key;
        o.node.textContent = "";
        if (key === "ph") {
          var bar = make("span", "lp-ph");
          bar.style.setProperty("--w", o.ph + "px");
          o.node.appendChild(bar);
        } else if (key !== "none") {
          var s = o.stages[k];
          var span = make("span", (s.pop && !reduce ? "lp-pop " : "") + (s.cls || ""));
          fill(span, s.parts, "lp-bad");
          o.node.appendChild(span);
        }
      });

      tabs.forEach(function (t, i) {
        t.classList.toggle("is-done", i < L);
        t.classList.toggle("is-active", i === L);
      });
      segs.forEach(function (s, i) {
        s.classList.toggle("is-done", i < L);
        s.classList.toggle("is-active", i === L);
      });
      verb.textContent = moving ? tabs[L].textContent.replace(/^\d+/, "") + ": " + tabs[L].getAttribute("data-verb") : "";
      status.textContent = L < 0 ? panel.getAttribute("data-raw")
        : moving ? panel.getAttribute("data-step").replace("{n}", L + 1).replace("{total}", tabs.length).replace("{tab}", tabs[L].textContent.replace(/^\d+/, ""))
        : panel.getAttribute("data-done");
      panel.classList.toggle("is-moving", moving);
      panel.classList.toggle("is-done", L >= tabs.length);

      // a fresh dot per step restarts the fall animation in both connectors
      panel.querySelectorAll(".lp-vconn").forEach(function (v, i) {
        var old = v.querySelector(".lp-drop");
        if (old) v.removeChild(old);
        if (moving && !reduce) {
          var dot = make("span", "lp-drop");
          dot.style.setProperty("--t", (STEP_MS * 0.4 / 1000).toFixed(2) + "s");
          dot.style.setProperty("--delay", (i * STEP_MS * 0.5 / 1000).toFixed(2) + "s");
          v.appendChild(dot);
        }
      });
    }

    function tick() {
      lane = lane >= last ? -1 : lane + 1;
      render();
    }
    function sync() {
      var run = playing && visible;
      if (run && !timer) timer = setInterval(tick, STEP_MS);
      if (!run && timer) { clearInterval(timer); timer = null; }
      toggle.textContent = toggle.getAttribute(playing ? "data-pause" : "data-play");
      panel.classList.toggle("is-paused", !playing);
    }

    toggle.addEventListener("click", function () { playing = !playing; sync(); });
    // reduced motion: show the finished file and no controls
    if (reduce) { lane = tabs.length; toggle.hidden = true; }
    render();
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (entries) {
        visible = entries[0].isIntersecting;
        sync();
      }, { threshold: 0.2 }).observe(panel);
    } else {
      visible = true;
    }
    sync();
  }

  function initTerm(term) {
    var copy = term.querySelector(".lp-copy");
    var label = copy.querySelector("span");
    var idle = label.textContent;
    copy.addEventListener("click", function () {
      function flash() {
        copy.classList.add("is-copied");
        label.textContent = copy.getAttribute("data-copied");
        setTimeout(function () { copy.classList.remove("is-copied"); label.textContent = idle; }, 2000);
      }
      if (navigator.clipboard) navigator.clipboard.writeText(copy.getAttribute("data-copy")).then(flash, function () {});
    });

    if (window.SAIRA_VERSION) {
      term.querySelectorAll("[data-saira-version]").forEach(function (v) { v.textContent = window.SAIRA_VERSION; });
    }
    if (reduce || !("IntersectionObserver" in window)) return;

    // typed lines keep their prompt span and receive the rest one character at a time
    var lines = [].slice.call(term.querySelectorAll(".lp-term-line")).map(function (node) {
      var parts = [].map.call(node.children, function (s) { return { text: s.textContent, cls: s.className }; });
      return { node: node, cmd: node.hasAttribute("data-cmd"), wait: Number(node.getAttribute("data-wait")) || 300, prompt: parts[0], parts: parts.slice(1) };
    });
    var cursor = make("span", "lp-cursor");
    lines.forEach(function (l) { l.node.classList.add("is-hidden"); });

    function type(l, n) {
      l.node.textContent = "";
      l.node.appendChild(make("span", l.prompt.cls, l.prompt.text));
      var left = n;
      l.parts.forEach(function (p) {
        if (left <= 0) return;
        var piece = p.text.slice(0, left);
        left -= piece.length;
        l.node.appendChild(make("span", p.cls, piece));
      });
      l.node.appendChild(cursor);
    }

    function play(i, n) {
      if (i >= lines.length) return;
      var l = lines[i];
      l.node.classList.remove("is-hidden");
      if (!l.cmd) {
        setTimeout(function () { play(i + 1, 0); }, l.wait);
        return;
      }
      var total = l.parts.reduce(function (sum, p) { return sum + p.text.length; }, 0);
      type(l, n);
      if (n < total) {
        setTimeout(function () { play(i, n + 1); }, 30);
      } else {
        setTimeout(function () {
          if (cursor.parentNode) cursor.parentNode.removeChild(cursor);
          play(i + 1, 0);
        }, l.wait);
      }
    }

    // plays once, when the window comes into view
    var seen = new IntersectionObserver(function (entries) {
      if (!entries[0].isIntersecting) return;
      seen.disconnect();
      setTimeout(function () { play(0, 0); }, 400);
    }, { threshold: 0.4 });
    seen.observe(term);
  }

  function init() {
    var flow = document.querySelector(".lp-flow");
    var term = document.querySelector(".lp-term");
    if (flow) initFlow(flow);
    if (term) initTerm(term);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

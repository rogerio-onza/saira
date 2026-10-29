// Landing page animations: the hero species, the flow panel (one sheet that
// the app tabs fix in place), the network map and the install console. All visible
// text comes from the page markup, so the PT, EN and ES pages share this file.
(function () {
  "use strict";

  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Text that changes swaps letter by letter through lowercase glyphs, like a
  // record field that migrates to a new value.
  var GLYPHS = "abcdefghijklmnopqrstuvwxyz";
  var SCRAMBLE_MS = 900;

  function scrambled(from, to, p) {
    var n = Math.max(from.length, to.length), out = "";
    for (var k = 0; k < n; k++) {
      var t = k / n * 0.6 + 0.35;
      if (p >= t) out += to.charAt(k);
      else if (p < t - 0.35) out += from.charAt(k) || " ";
      else out += (to.charAt(k) === " " || from.charAt(k) === " ") ? " " : GLYPHS.charAt(Math.floor(Math.random() * GLYPHS.length));
    }
    return out.replace(/\s+$/, "");
  }

  function scramble(node, from, to, onFrame, ms) {
    cancelAnimationFrame(node.lpScramble);
    var t0 = performance.now(), span = ms || SCRAMBLE_MS;
    function step(now) {
      var p = Math.min(1, (now - t0) / span);
      node.textContent = p < 1 ? scrambled(from, to, p) : to;
      if (onFrame) onFrame(p);
      if (p < 1) node.lpScramble = requestAnimationFrame(step);
    }
    node.lpScramble = requestAnimationFrame(step);
  }

  // Real GBIF records of the hero species, in the hero order. Raw cells are
  // [before, bad part, after], with errors inserted for the demo. All six are
  // on the MMA list, so the export generalizes their coordinates to 0.1 degree.
  var ROWS = [
    { raw: [["Podocnemis sextuberculat", "ta", ""], ["-2", ",", "82514"], ["-64", ",", "889433"], ["", "11/08/2004", ""], ["Amazonas", "", ""]],
      fix: ["Podocnemis sextuberculata", "-2.82514", "-64.889433", "2004-08-11", "Amazonas"], gen: ["-2.8", "-64.9"], cat: "EN" },
    { raw: [["Micranthocereus p", "i", "lyanthus"], ["", "-42.595426", ""], ["", "-14.321965", ""], ["", "24/07/2023", ""], ["Bahia", "", ""]],
      fix: ["Micranthocereus polyanthus", "-14.321965", "-42.595426", "2023-07-24", "Bahia"], gen: ["-14.3", "-42.6"], cat: "EN" },
    { raw: [["Boana buriti", "", ""], ["-16", ",", "787468"], ["-47", ",", "781879"], ["", "17/12/2025", ""], ["Goi", "Ã¡", "s"]],
      fix: ["Boana buriti", "-16.787468", "-47.781879", "2025-12-17", "Goiás"], gen: ["-16.8", "-47.8"], cat: "VU" },
    { raw: [["Tangara fastuosa", "", ""], ["-6", ",", "931549"], ["-35", ",", "718407"], ["", "28/07/2019", ""], ["Para", "Ã­", "ba"]],
      fix: ["Tangara fastuosa", "-6.931549", "-35.718407", "2019-07-28", "Paraíba"], gen: ["-6.9", "-35.7"], cat: "VU" },
    { raw: [["Acanthochelys macroce", "f", "ala"], ["", "-17.061441", ""], ["", "-56.813209", ""], ["", "01/08/2022", ""], ["Mato Grosso", "", ""]],
      fix: ["Acanthochelys macrocephala", "-17.061441", "-56.813209", "2022-08-01", "Mato Grosso"], gen: ["-17.1", "-56.8"], cat: "VU" },
    { raw: [["Leopardus munoai", "", ""], ["-30", ",", "225021"], ["-54", ",", "345336"], ["", "27/01/2017", ""], ["Rio Grande do Sul", "", ""]],
      fix: ["Leopardus munoai", "-30.225021", "-54.345336", "2017-01-27", "Rio Grande do Sul"], gen: ["-30.2", "-54.3"], cat: "CR" }
  ];
  var TERMS = ["scientificName", "decimalLatitude", "decimalLongitude", "eventDate", "stateProvince"];
  var STOP = {};

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

  // Waits that count only while `live` is true (playing and on screen). A new
  // token stops the old loop at its next wait.
  function clock() {
    var c = { token: 0, live: false };
    c.wait = function (tok, ms) {
      return new Promise(function (resolve, reject) {
        var left = ms, last = performance.now();
        (function tick() {
          if (tok !== c.token) { reject(STOP); return; }
          var now = performance.now();
          if (c.live) left -= now - last;
          last = now;
          if (left <= 0) resolve(); else setTimeout(tick, Math.min(left, 100));
        })();
      });
    };
    return c;
  }
  function quiet(e) { if (e !== STOP) throw e; }

  // Flow: one sheet that the seven tabs fix in place, column by column.
  function initFlow(panel) {
    var tabs = [].slice.call(panel.querySelectorAll(".lp-tabs li"));
    var names = tabs.map(function (t) { return t.textContent.replace(/^\d+/, ""); });
    var verb = panel.querySelector(".lp-verb");
    var status = panel.querySelector(".lp-status");
    var toggle = panel.querySelector(".lp-toggle");
    var cap = panel.querySelector(".lp-cap");
    var grid = panel.querySelector(".lp-grid");
    var cols = grid.getAttribute("data-cols").split("|");
    var capRaw = cap.textContent;
    var C = clock(), playing = !reduce, visible = false, started = false;
    var ALL = ROWS.map(function (_, r) { return r; });

    function row(label) {
      var r = make("div", "lp-row");
      r.setAttribute("role", "row");
      r.appendChild(make("span", "lp-num", label));
      grid.appendChild(r);
      return r;
    }
    function cellsOf(r, header) {
      var out = [];
      for (var k = 0; k < 6; k++) {
        var c = make("span", "lp-cell");
        c.setAttribute("role", header ? "columnheader" : "cell");
        r.appendChild(c);
        out.push(c);
      }
      return out;
    }
    var head = cellsOf(row("1"), true);
    var cells = ROWS.map(function (_, r) { return cellsOf(row(String(r + 2)), false); });

    function dyn(r) { return '{"mmaThreatStatus":"' + ROWS[r].cat + '"}'; }
    function setTabs(L) {
      tabs.forEach(function (t, i) {
        t.classList.toggle("is-active", i === L);
        t.classList.toggle("is-done", i < L);
      });
      verb.textContent = "";
      if (L >= 0 && L < tabs.length) {
        verb.appendChild(make("b", null, names[L]));
        verb.appendChild(document.createTextNode(" " + tabs[L].getAttribute("data-verb")));
        status.textContent = panel.getAttribute("data-step").replace("{n}", L + 1).replace("{total}", tabs.length).replace("{tab}", names[L]);
      }
    }
    function reset() {
      panel.classList.remove("is-done");
      cap.textContent = capRaw;
      head.forEach(function (c, i) {
        c.textContent = i < 5 ? cols[i] : "dynamicProperties";
        c.className = "lp-cell" + (i === 5 ? " lp-dyn" : "");
      });
      cells.forEach(function (line, r) {
        line.forEach(function (c, i) {
          c.className = "lp-cell";
          if (i < 5) fill(c, ROWS[r].raw[i], "lp-bad");
          else { c.textContent = dyn(r); c.classList.add("lp-dyn"); }
        });
      });
      setTabs(-1);
      status.textContent = panel.getAttribute("data-raw");
    }
    // reduced motion: the finished file, with no controls
    function finished() {
      head.forEach(function (c, i) { c.textContent = i < 5 ? TERMS[i] : "dynamicProperties"; });
      cells.forEach(function (line, r) {
        var d = ROWS[r];
        [d.fix[0], d.gen[0], d.gen[1], d.fix[3], d.fix[4], dyn(r)].forEach(function (v, i) { line[i].textContent = v; });
        line[0].classList.add("lp-italic");
        line[5].classList.add("is-open");
      });
      head[5].classList.add("is-open");
      setTabs(tabs.length);
      cap.textContent = "occurrence.txt";
      status.textContent = panel.getAttribute("data-done");
      panel.classList.add("is-done");
    }

    function hot(cell) {
      cell.classList.add("is-hot");
      setTimeout(function () { cell.classList.remove("is-hot"); }, 900);
    }
    // one column, row after row; `rows` are the rows that change at this tab
    async function col(tok, c, rows, value, extra) {
      for (var i = 0; i < rows.length; i++) {
        var cell = cells[rows[i]][c];
        hot(cell);
        if (extra) cell.classList.add(extra);
        scramble(cell, cell.textContent, value(rows[i]), null, 650);
        await C.wait(tok, 140);
      }
    }
    function bad(c) { return ALL.filter(function (r) { return !!ROWS[r].raw[c][1]; }); }
    function pick(k, field) { return function (r) { return ROWS[r][field][k]; }; }

    async function step(tok, L) {
      if (L === 0) await col(tok, 4, bad(4), pick(4, "fix"));
      if (L === 1) {
        for (var k = 0; k < 5; k++) { hot(head[k]); scramble(head[k], head[k].textContent, TERMS[k], null, 650); await C.wait(tok, 130); }
      }
      if (L === 2) {
        for (var r = 0; r < cells.length; r++) {
          cells[r].slice(0, 5).forEach(function (c) { c.classList.add("is-hot"); });
          await C.wait(tok, 170);
          cells[r].forEach(function (c) { c.classList.remove("is-hot"); });
        }
      }
      if (L === 3) await col(tok, 0, ALL, pick(0, "fix"), "lp-italic");
      if (L === 4 || L === 5) {
        var field = L === 4 ? "fix" : "gen";
        col(tok, 1, ALL, pick(L === 4 ? 1 : 0, field)).catch(quiet);
        await C.wait(tok, 80);
        await col(tok, 2, ALL, pick(L === 4 ? 2 : 1, field));
      }
      if (L === 6) {
        await col(tok, 3, ALL, pick(3, "fix"));
        head[5].classList.add("is-open");
        for (var d = 0; d < cells.length; d++) { cells[d][5].classList.add("is-open"); await C.wait(tok, 110); }
      }
    }

    async function run(tok) {
      for (;;) {
        reset();
        await C.wait(tok, 1000);
        for (var L = 0; L < tabs.length; L++) {
          setTabs(L);
          var t0 = performance.now();
          await step(tok, L);
          // each tab stays at least 1.9 s, so the reader can follow the verb
          await C.wait(tok, Math.max(300, 1900 - (performance.now() - t0)));
        }
        setTabs(tabs.length);
        scramble(cap, cap.textContent, "occurrence.txt", null, 700);
        panel.classList.add("is-done");
        status.textContent = panel.getAttribute("data-done");
        await C.wait(tok, 4500);
      }
    }

    function sync() {
      C.live = playing && visible;
      if (C.live && !started) { started = true; run(++C.token).catch(quiet); }
      toggle.textContent = toggle.getAttribute(playing ? "data-pause" : "data-play");
      panel.classList.toggle("is-paused", !playing);
    }

    if (reduce) { reset(); finished(); toggle.hidden = true; return; }
    reset();
    toggle.addEventListener("click", function () { playing = !playing; sync(); });
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (entries) {
        visible = entries[0].isIntersecting;
        sync();
      }, { threshold: 0.25 }).observe(panel);
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

    // the script is on screen from the start; only the output replays, in about 3 s
    var outs = [].slice.call(term.querySelectorAll("[data-out]"));
    outs.forEach(function (l) { l.classList.add("is-hidden"); });

    function play(i) {
      if (i >= outs.length) return;
      var l = outs[i], bar = l.querySelector(".lp-term-prog");
      l.classList.remove("is-hidden");
      if (bar) { void bar.offsetWidth; bar.classList.add("is-on"); }
      setTimeout(function () { play(i + 1); }, Number(l.getAttribute("data-wait")) || 0);
    }

    // plays once, when the window comes into view
    var seen = new IntersectionObserver(function (entries) {
      if (!entries[0].isIntersecting) return;
      seen.disconnect();
      setTimeout(function () { play(0); }, 500);
    }, { threshold: 0.4 });
    seen.observe(term);
  }

  // Install tabs. The visitor's system opens first: Linux opens the Linux app,
  // macOS the R package (there is no macOS app).
  function initInstall(box) {
    var tabs = [].slice.call(box.querySelectorAll('[role="tab"]'));
    function select(tab, focus) {
      tabs.forEach(function (t) {
        var on = t === tab;
        t.setAttribute("aria-selected", on ? "true" : "false");
        t.tabIndex = on ? 0 : -1;
        document.getElementById(t.getAttribute("aria-controls")).hidden = !on;
      });
      if (focus) tab.focus();
    }
    tabs.forEach(function (t, i) {
      t.addEventListener("click", function () { select(t); });
      t.addEventListener("keydown", function (e) {
        var k = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
        if (!k) return;
        e.preventDefault();
        select(tabs[(i + k + tabs.length) % tabs.length], true);
      });
    });
    var ua = navigator.userAgent;
    var os = /Android|iPhone|iPad/.test(ua) ? "" : /Linux/.test(ua) ? "linux" : /Mac OS X/.test(ua) ? "r" : "";
    var first = os && box.querySelector('[data-os="' + os + '"]');
    if (first) select(first);
  }

  // Hero: one photo per biome. The next photo comes into focus while the
  // last one goes soft, and the record card fades between species.
  var FADE_MS = 350;

  function initHero(hero) {
    var photos = [].slice.call(hero.querySelectorAll(".lp-photo"));
    var tabs = [].slice.call(hero.querySelectorAll(".lp-biome"));
    var rec = {
      box: hero.querySelector(".lp-rec"),
      name: hero.querySelector(".lp-rec-name"), line: hero.querySelector(".lp-rec-line"),
      cat: hero.querySelector(".lp-rec-cat"), credit: hero.querySelector(".lp-rec-credit span")
    };
    var dur = (Number(hero.getAttribute("data-seconds")) || 7) * 1000;
    var i = 0, timer = null, left = dur, t0 = 0, holds = {}, fade = null;
    tabs.forEach(function (t, k) { if (t.getAttribute("aria-pressed") === "true") i = k; });
    hero.style.setProperty("--dur", dur / 1000 + "s");

    function record(k) {
      var t = tabs[k];
      return {
        name: t.getAttribute("data-sci"),
        line: t.getAttribute("data-fam") + " · " + t.getAttribute("data-uf"),
        cat: t.getAttribute("data-cat"), code: t.getAttribute("data-code"), credit: t.getAttribute("data-credit")
      };
    }

    // prev is the photo that goes soft under the next one, or -1 for a cut
    function show(k, prev) {
      photos.forEach(function (p, j) {
        p.classList.toggle("is-on", j === k);
        p.classList.toggle("is-in", j === k && prev >= 0);
        p.classList.toggle("is-prev", j === prev);
        if (j === k) p.removeAttribute("aria-hidden"); else p.setAttribute("aria-hidden", "true");
      });
    }

    function loaded(img) { return img.complete && img.naturalWidth > 0; }

    function fill(to) {
      rec.name.textContent = to.name; rec.line.textContent = to.line; rec.credit.textContent = to.credit;
      rec.cat.textContent = to.cat; rec.cat.setAttribute("data-code", to.code);
    }

    function go(n) {
      if (n === i) return;
      var to = record(n), prev = i;
      i = n;
      tabs.forEach(function (t, k) {
        t.classList.toggle("is-on", k === i);
        t.classList.toggle("is-done", k < i);
        t.setAttribute("aria-pressed", k === i ? "true" : "false");
      });
      // a photo that is still loading has nothing to focus, so it cuts in
      show(n, !reduce && loaded(photos[n]) ? prev : -1);
      clearTimeout(fade);
      if (reduce) fill(to);
      else {
        rec.box.classList.add("is-out");
        fade = setTimeout(function () { fill(to); rec.box.classList.remove("is-out"); }, FADE_MS);
      }
      left = dur;
      if (timer) { clearTimeout(timer); timer = null; run(); }
    }

    // Autoplay stops while the reader points at the tabs, scrolls away or
    // leaves the page, and resumes with the time that was left.
    function held() { for (var r in holds) if (holds[r]) return true; return false; }
    function run() {
      if (reduce || held()) return;
      t0 = Date.now();
      timer = setTimeout(function () { timer = null; go((i + 1) % tabs.length); run(); }, left);
    }
    function hold(reason, on) {
      var was = held();
      holds[reason] = on;
      if (held() === was) return;
      hero.classList.toggle("is-held", !was);
      if (!was && timer) { clearTimeout(timer); timer = null; left = Math.max(0, left - (Date.now() - t0)); }
      if (was) run();
    }

    tabs.forEach(function (t, k) {
      t.addEventListener("click", function () { go(k); if (!timer) run(); });
    });
    var nav = hero.querySelector(".lp-biomes");
    nav.addEventListener("mouseenter", function () { hold("hover", true); });
    nav.addEventListener("mouseleave", function () { hold("hover", false); });
    nav.addEventListener("focusin", function () { hold("focus", true); });
    nav.addEventListener("focusout", function () { hold("focus", false); });
    document.addEventListener("visibilitychange", function () { hold("page", document.hidden); });
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (entries) { hold("view", !entries[0].isIntersecting); }, { threshold: 0.2 }).observe(hero);
    }

    tabs[i].classList.add("is-on");
    tabs.forEach(function (t, k) { if (k < i) t.classList.add("is-done"); });
    // the other photos load after the page, so the first paint stays light
    function preload() { photos.forEach(function (p) { if (p.hasAttribute("data-src")) p.src = p.getAttribute("data-src"); }); }
    if (document.readyState === "complete") preload(); else window.addEventListener("load", preload);
    run();
  }

  // Map: faint sparks over the occurrence density and a crosshair that visits
  // the six table species, one at a time, with their generalized coordinates.
  function initMap(fig) {
    var pins = [].slice.call(fig.querySelectorAll(".lp-pin"));
    var cards = [].slice.call(fig.querySelectorAll(".lp-card"));
    var light = fig.querySelector(".lp-map-light");
    cards.forEach(function (c, i) { c.querySelector(".lp-card-xy").textContent = ROWS[i].gen.join(", "); });
    if (reduce || !("IntersectionObserver" in window)) return;

    var gh = make("span", "lp-guide is-h"), gv = make("span", "lp-guide is-v");
    var al = make("span", "lp-axis is-lat"), ao = make("span", "lp-axis is-lon");
    [gh, gv, al, ao].forEach(function (n) { n.setAttribute("aria-hidden", "true"); fig.appendChild(n); });
    var cv = make("canvas", "lp-sparks");
    cv.setAttribute("aria-hidden", "true");
    fig.insertBefore(cv, pins[0]);
    var C = clock(), started = false, drawing = false;

    async function mira(tok) {
      for (var i = 0; ; i = (i + 1) % pins.length) {
        var x = pins[i].style.getPropertyValue("--x"), y = pins[i].style.getPropertyValue("--y");
        pins.forEach(function (p, k) { p.classList.toggle("is-dim", k !== i); p.classList.remove("is-lock"); });
        cards.forEach(function (c) { c.classList.remove("is-on"); });
        gh.style.top = al.style.top = y;
        gv.style.left = ao.style.left = x;
        al.textContent = ROWS[i].gen[0] + "°";
        ao.textContent = ROWS[i].gen[1] + "°";
        [gh, gv, al, ao].forEach(function (n) { n.classList.add("is-on"); });
        await C.wait(tok, 650);
        void pins[i].offsetWidth;
        pins[i].classList.add("is-lock");
        await C.wait(tok, 500);
        cards[i].classList.add("is-on");
        await C.wait(tok, 2600);
      }
    }

    // Sparks pick a 20 px square (about 1.5 degrees) that has data, then a
    // pixel inside it. Pixel by pixel, the dense coast would get most sparks.
    var squares = null, sparks = [], color = "", frames = 0;
    function sample(done) {
      var img = new Image();
      img.onload = function () {
        try {
          var W = 300, H = Math.round(W * img.naturalHeight / img.naturalWidth);
          var c = make("canvas"); c.width = W; c.height = H;
          var x = c.getContext("2d");
          x.drawImage(img, 0, 0, W, H);
          var px = x.getImageData(0, 0, W, H).data, by = {};
          for (var yy = 0; yy < H; yy++) {
            for (var xx = 0; xx < W; xx++) {
              var k = (yy * W + xx) * 4;
              // the density colors are blue; land and sea are not
              if (px[k + 2] - px[k] > 70 && px[k + 2] > 140) {
                var key = (xx / 20 | 0) + ":" + (yy / 20 | 0);
                (by[key] = by[key] || []).push([xx / W, yy / H]);
              }
            }
          }
          squares = Object.keys(by).map(function (key) { return by[key]; });
        } catch (e) { squares = []; }
        done();
      };
      img.onerror = function () { squares = []; done(); };
      img.src = light.currentSrc || light.src;
    }
    function frame() {
      if (!C.live || !squares.length) { drawing = false; return; }
      var W = cv.clientWidth, H = cv.clientHeight, dpr = window.devicePixelRatio || 1;
      if (cv.width !== Math.round(W * dpr)) { cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr); }
      // the theme can change at any time, so the color is read again now and then
      if (frames++ % 30 === 0) color = getComputedStyle(fig).getPropertyValue("--lp-glow").trim();
      var x = cv.getContext("2d"), now = performance.now();
      x.setTransform(dpr, 0, 0, dpr, 0, 0);
      x.clearRect(0, 0, W, H);
      for (var n = 0; n < 3; n++) {
        var sq = squares[Math.random() * squares.length | 0], s = sq[Math.random() * sq.length | 0];
        sparks.push([s[0] * W, s[1] * H, now, 700 + Math.random() * 900]);
      }
      sparks = sparks.filter(function (s) { return now - s[2] < s[3]; });
      x.fillStyle = color;
      sparks.forEach(function (s) {
        var a = Math.sin((now - s[2]) / s[3] * Math.PI);
        x.globalAlpha = a * 0.55;
        x.beginPath();
        x.arc(s[0], s[1], 1.2 + a * 1.3, 0, 7);
        x.fill();
      });
      x.globalAlpha = 1;
      requestAnimationFrame(frame);
    }
    function draw() {
      if (drawing || !C.live || !squares) return;
      drawing = true;
      requestAnimationFrame(frame);
    }

    new IntersectionObserver(function (entries) {
      C.live = entries[0].isIntersecting;
      if (C.live && !started) {
        started = true;
        fig.classList.add("is-live");
        mira(++C.token).catch(quiet);
        sample(draw);
      }
      draw();
    }, { threshold: 0.35 }).observe(fig);
  }

  function init() {
    var hero = document.querySelector(".lp-hero");
    var map = document.querySelector(".lp-mapfig");
    var flow = document.querySelector(".lp-flow");
    var term = document.querySelector(".lp-term");
    var get = document.querySelector(".lp-get");
    if (hero) initHero(hero);
    if (map) initMap(map);
    if (flow) initFlow(flow);
    if (get) initInstall(get);
    if (term) initTerm(term);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

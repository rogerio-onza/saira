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

  // Why open data matters: each use lights in turn, then all five stay lit.
  // The loop stops out of view and starts again from the first use.
  function initWhy(sec) {
    var uses = [].slice.call(sec.querySelectorAll(".lp-use"));
    var num = sec.querySelector("[data-count]");
    if (reduce || !("IntersectionObserver" in window)) {
      uses.forEach(function (u) { u.classList.add("is-seen"); });
      return;
    }
    var token = 0, counted = false;

    function wait(tok, ms) {
      return new Promise(function (res, rej) { setTimeout(function () { tok === token ? res() : rej(STOP); }, ms); });
    }
    function count() {
      var to = Number(num.getAttribute("data-count")), t0 = performance.now();
      (function step(now) {
        var p = Math.min(1, (now - t0) / 1200);
        num.textContent = "+" + Math.round(to * (1 - Math.pow(1 - p, 3)));
        if (p < 1) requestAnimationFrame(step);
      })(t0);
    }
    async function loop(tok) {
      for (;;) {
        uses.forEach(function (u) { u.classList.remove("is-on", "is-seen", "is-drawn"); });
        await wait(tok, 300);
        for (var i = 0; i < uses.length; i++) {
          void uses[i].offsetWidth;
          uses[i].classList.add("is-drawn", "is-on");
          await wait(tok, 1400);
          uses[i].classList.remove("is-on");
          uses[i].classList.add("is-seen");
        }
        await wait(tok, 2600);
      }
    }
    new IntersectionObserver(function (entries) {
      var tok = ++token;
      if (!entries[0].isIntersecting) return;
      if (!counted && num) { counted = true; count(); }
      loop(tok).catch(quiet);
    }, { threshold: 0.35 }).observe(sec);
  }

  // Hero: one photo per biome. The next photo comes in as a plumage: each
  // hexagon turns like a feather scale, first around the subject of the next
  // photo, shines in the colors of the saíra-sete-cores and shows the next
  // species on its back. The record fields scramble at the same time.
  var TURN_MS = 3400;

  var VERT = "attribute vec2 a; void main() { gl_Position = vec4(a, 0.0, 1.0); }";
  var FRAG = `
precision highp float;
uniform sampler2D texA, texB, cells;
uniform vec2 res, sizeA, sizeB, posA, posB, dim, focus;
uniform float t, cell, hexS;
const float PI = 3.14159265;

// object-fit: cover with object-position, in device pixels from the bottom left
vec2 cover(vec2 p, vec2 sz, vec2 pos) {
  float s = max(res.x / sz.x, res.y / sz.y);
  vec2 sc = sz * s;
  return (p - (res - sc) * vec2(pos.x, 1.0 - pos.y)) / sc;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Pointy-top hexagons with center spacing 1. hexd is 0.5 on the edge.
float hexd(vec2 p) { p = abs(p); return max(dot(p, vec2(0.5, 0.8660254)), p.x); }
vec2 hexCenter(vec2 uv) {
  vec2 r = vec2(1.0, 1.7320508);
  vec2 ga = mod(uv, r) - 0.5 * r;
  vec2 gb = mod(uv - 0.5 * r, r) - 0.5 * r;
  return uv - (dot(ga, ga) < dot(gb, gb) ? ga : gb);
}

// Turquoise, green, gold and violet blue, in a loop.
vec3 sheen(float x) {
  x = fract(x) * 4.0;
  vec3 c0 = vec3(0.2, 0.85, 0.95), c1 = vec3(0.4, 0.9, 0.45), c2 = vec3(1.0, 0.68, 0.22), c3 = vec3(0.5, 0.42, 1.0);
  if (x < 1.0) return mix(c0, c1, x);
  if (x < 2.0) return mix(c1, c2, x - 1.0);
  if (x < 3.0) return mix(c2, c3, x - 2.0);
  return mix(c3, c0, x - 3.0);
}

void main() {
  vec2 p = gl_FragCoord.xy;
  vec2 uv = p / hexS;
  vec2 hid = hexCenter(uv);
  vec2 c = hid * hexS;
  vec2 q = uv - hid;
  float T = texture2D(cells, (clamp(floor(c / cell), vec2(0.0), dim - 1.0) + 0.5) / dim).r;
  float ph = clamp((t - 0.03 - 0.62 * T) / 0.24, 0.0, 1.0);
  ph = ph * ph * (3.0 - 2.0 * ph);
  float th = PI * ph;
  float cs = cos(th), sn = sin(th);
  // The axis snaps to a mirror line of the hexagon, so the tile lands back on the grid.
  vec2 d = c - focus;
  float ang = atan(d.y, d.x + 0.001) + 0.5 * PI;
  ang = floor(ang / (PI / 6.0) + 0.5) * (PI / 6.0);
  vec2 ax = vec2(cos(ang), sin(ang));
  vec2 nx = vec2(-ax.y, ax.x);
  // Perspective view of a tile that turns about ax, solved for tile coordinates.
  float X = dot(q, nx), Y = dot(q, ax);
  float f = 4.5;
  float den = f * cs + X * sn;
  den = (den < 0.0 ? -1.0 : 1.0) * max(abs(den), 1e-4);
  float u = X * f / den;
  float v = Y * (f - u * sn) / f;
  vec2 w = u * nx + v * ax;
  // Sample the mipmapped photos before any branch.
  vec3 fa = texture2D(texA, cover(c + w * hexS, sizeA, posA)).rgb;
  vec3 fb = texture2D(texB, cover(c + (v * ax - u * nx) * hexS, sizeB, posB)).rgb;
  vec3 b = texture2D(texB, cover(p, sizeB, posB)).rgb;
  // Near rest the tile overlaps its neighbors a little, so no hairline gaps show.
  float edge = 0.5 - 0.035 * sn + 0.03 * (1.0 - smoothstep(0.0, 0.15, sn));
  float inside = step(hexd(w), edge);
  vec3 face = cs > 0.0 ? fa : fb;
  face *= 0.62 + 0.38 * abs(cs) + 0.25 * sn * dot(nx, vec2(-0.6, 0.8));
  float band = exp(-pow((dot(w, nx) - (0.9 - 1.8 * ph)) / 0.24, 2.0));
  vec3 glint = sheen(0.2 * hash(hid) + 0.5 * ph + 0.7 * dot(w, ax));
  face = 1.0 - (1.0 - face) * (1.0 - glint * 0.8 * sn * band);
  face = mix(face, glint, 0.55 * sn * smoothstep(edge - 0.06, edge, hexd(w)));
  vec3 col = mix(vec3(0.025, 0.03, 0.035), face, inside);
  gl_FragColor = vec4(mix(col, b, smoothstep(0.975, 1.0, t)), 1.0);
}`;

  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  // WebGL stage of the hero. Without WebGL it returns null, and the hero
  // swaps the photos at once.
  function plumage(canvas) {
    var gl = canvas.getContext("webgl", { alpha: false, antialias: false });
    if (!gl) return null;
    function shader(type, src) {
      var s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      return s;
    }
    var prog = gl.createProgram();
    gl.attachShader(prog, shader(gl.VERTEX_SHADER, VERT));
    gl.attachShader(prog, shader(gl.FRAGMENT_SHADER, FRAG));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return null;
    gl.useProgram(prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
    var at = gl.getAttribLocation(prog, "a");
    gl.enableVertexAttribArray(at);
    gl.vertexAttribPointer(at, 2, gl.FLOAT, false, 0, 0);
    var U = {};
    ["texA", "texB", "cells", "res", "sizeA", "sizeB", "posA", "posB", "dim", "focus", "t", "cell", "hexS"].forEach(function (n) {
      U[n] = gl.getUniformLocation(prog, n);
    });
    gl.uniform1i(U.texA, 0);
    gl.uniform1i(U.texB, 1);
    gl.uniform1i(U.cells, 2);
    var cells = gl.createTexture(), cache = [], raf = 0, pending = null, lost = false;

    function params(filter, min) {
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, min);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    }

    // A power-of-two copy with mipmaps, so the small turning tiles stay smooth.
    // Two photos play at once, and the cache keeps one more.
    function photo(img) {
      for (var k = 0; k < cache.length; k++) {
        if (cache[k].img === img) { var hit = cache.splice(k, 1)[0]; cache.push(hit); return hit.tex; }
      }
      var c = make("canvas");
      c.width = 2048; c.height = 1024;
      c.getContext("2d").drawImage(img, 0, 0, 2048, 1024);
      var tex = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, c);
      gl.generateMipmap(gl.TEXTURE_2D);
      params(gl.LINEAR, gl.LINEAR_MIPMAP_LINEAR);
      cache.push({ img: img, tex: tex });
      while (cache.length > 3) gl.deleteTexture(cache.shift().tex);
      return tex;
    }

    // When each grid cell turns: first around the subject of the next photo,
    // then around two or three other spots, like records that come in clusters.
    function grid(W, H, focus, seed) {
      var size = Math.max(18, Math.round(Math.max(W, H) / 46));
      var cols = Math.ceil(W / size), rows = Math.ceil(H / size), rand = mulberry32(seed);
      var spots = [{ x: focus[0] * cols, y: focus[1] * rows, t0: 0 }];
      for (var s = 1, n = 3 + Math.floor(rand() * 2); s < n; s++) spots.push({ x: rand() * cols, y: rand() * rows, t0: 0.18 + rand() * 0.3 });
      var spread = Math.max(cols, rows) * 0.75, when = new Float32Array(cols * rows), max = 0;
      for (var j = 0; j < rows; j++) {
        for (var i = 0; i < cols; i++) {
          var v = Infinity;
          for (var k = 0; k < spots.length; k++) v = Math.min(v, spots[k].t0 + Math.hypot(i - spots[k].x, j - spots[k].y) / spread);
          v += (rand() - 0.5) * 0.12;
          if (rand() < 0.02) v = rand() * 0.35;
          when[j * cols + i] = Math.max(v, 0);
          max = Math.max(max, when[j * cols + i]);
        }
      }
      var data = new Uint8Array(cols * rows * 4);
      for (var m = 0; m < cols * rows; m++) data[m * 4] = Math.round(when[m] / max * 255);
      gl.activeTexture(gl.TEXTURE2);
      gl.bindTexture(gl.TEXTURE_2D, cells);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, cols, rows, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);
      params(gl.NEAREST, gl.NEAREST);
      gl.uniform2f(U.dim, cols, rows);
      gl.uniform1f(U.cell, size);
    }

    function pos(img) {
      var p = (img.style.objectPosition || "50% 50%").split(" ");
      return [parseFloat(p[0]) / 100, parseFloat(p[1]) / 100];
    }

    // A lost context ends the turn on its own photo, and later swaps have no turn.
    canvas.addEventListener("webglcontextlost", function () {
      lost = true;
      cancelAnimationFrame(raf);
      if (pending) { var done = pending; pending = null; done(); }
    });

    return {
      // Turns photo a into photo b, then calls done. False when it cannot play.
      play: function (a, b, seed, done) {
        if (lost) return false;
        var unit = Math.min(window.devicePixelRatio || 1, 1.5);
        var W = Math.round(canvas.clientWidth * unit), H = Math.round(canvas.clientHeight * unit);
        canvas.width = W; canvas.height = H;
        gl.viewport(0, 0, W, H);
        var ta = photo(a), tb = photo(b), pa = pos(a), pb = pos(b);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, ta);
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, tb);
        grid(W, H, [pb[0], 1 - pb[1]], seed);
        gl.uniform2f(U.res, W, H);
        gl.uniform2f(U.sizeA, a.naturalWidth, a.naturalHeight);
        gl.uniform2f(U.sizeB, b.naturalWidth, b.naturalHeight);
        gl.uniform2f(U.posA, pa[0], pa[1]);
        gl.uniform2f(U.posB, pb[0], pb[1]);
        gl.uniform2f(U.focus, pb[0] * W, (1 - pb[1]) * H);
        // the long side sets the size, so a tall phone hero keeps large tiles
        gl.uniform1f(U.hexS, Math.max(24, Math.max(W, H) / 34));
        var t0 = performance.now();
        function frame(now) {
          var t = Math.min(1, (now - t0) / TURN_MS);
          gl.uniform1f(U.t, t);
          gl.drawArrays(gl.TRIANGLES, 0, 6);
          if (t < 1) raf = requestAnimationFrame(frame);
          else { pending = null; done(); }
        }
        pending = done;
        frame(t0);
        return true;
      },
      stop: function () { cancelAnimationFrame(raf); pending = null; }
    };
  }

  function initHero(hero) {
    var photos = [].slice.call(hero.querySelectorAll(".lp-photo"));
    var tabs = [].slice.call(hero.querySelectorAll(".lp-biome"));
    var canvas = hero.querySelector(".lp-gl");
    var stage = reduce ? null : plumage(canvas);
    var rec = {
      name: hero.querySelector(".lp-rec-name"), line: hero.querySelector(".lp-rec-line"),
      cat: hero.querySelector(".lp-rec-cat"), credit: hero.querySelector(".lp-rec-credit span")
    };
    var dur = (Number(hero.getAttribute("data-seconds")) || 7) * 1000;
    var i = 0, timer = null, left = dur, t0 = 0, holds = {};
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

    function show(k) {
      photos.forEach(function (p, j) {
        p.classList.toggle("is-on", j === k);
        if (j === k) p.removeAttribute("aria-hidden"); else p.setAttribute("aria-hidden", "true");
      });
      canvas.classList.remove("is-on");
    }

    function loaded(img) { return img.complete && img.naturalWidth > 0; }

    function go(n) {
      if (n === i) return;
      var from = record(i), to = record(n), a = photos[i], b = photos[n], seed = i * 31 + n * 17 + 5;
      // a turn still running ends at once on its own photo
      if (stage) stage.stop();
      show(i);
      i = n;
      tabs.forEach(function (t, k) {
        t.classList.toggle("is-on", k === i);
        t.classList.toggle("is-done", k < i);
        t.setAttribute("aria-pressed", k === i ? "true" : "false");
      });
      rec.credit.textContent = to.credit;
      if (stage && loaded(a) && loaded(b) && stage.play(a, b, seed, function () { show(n); })) {
        canvas.classList.add("is-on");
        scramble(rec.name, from.name, to.name);
        scramble(rec.line, from.line, to.line, function (p) { if (p >= 0.6) { rec.cat.textContent = to.cat; rec.cat.setAttribute("data-code", to.code); } });
      } else {
        show(n);
        rec.name.textContent = to.name; rec.line.textContent = to.line; rec.cat.textContent = to.cat; rec.cat.setAttribute("data-code", to.code);
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
    var why = document.querySelector(".lp-why");
    if (hero) initHero(hero);
    if (map) initMap(map);
    if (flow) initFlow(flow);
    if (why) initWhy(why);
    if (term) initTerm(term);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

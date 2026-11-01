// Run progress on the Names and Coordinates pages (ADR-160). During a run
// the server sends small messages, and this file draws them in place. A
// re-render of the card would lose the canvas state and flash.
(function () {
  "use strict";

  function reducedMotion() {
    return !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  }

  function token(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  // Size the canvas to its box. Returns the CSS size, or null when hidden.
  function fitCanvas(canvas, box) {
    var w = box.clientWidth;
    var h = box.clientHeight;
    if (!w || !h) return null;
    var dpr = window.devicePixelRatio || 1;
    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
    }
    var ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    return { w: w, h: h, ctx: ctx };
  }

  // Pointy-top hexagon, as in the hero of the help site (landing.js).
  function hexPath(ctx, cx, cy, r) {
    for (var i = 0; i < 6; i++) {
      var a = Math.PI / 3 * i - Math.PI / 2;
      var x = cx + r * Math.cos(a);
      var y = cy + r * Math.sin(a);
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.closePath();
  }

  /* ---------------- Names: one cell per name ---------------- */

  var NAME_COLORS = { a: "--success", s: "--info", m: "--warning", n: "--error" };
  var names = { msg: null, raf: 0 };

  // Honeycomb of n cells in a w x h box. The radius comes from the free
  // area and the count of names: 24 px for a short list, down to 3.5 px.
  // When the smallest cells do not fit, one cell holds several names.
  function hexGrid(r, w, h) {
    var gap = r >= 8 ? 3 : r >= 5 ? 2 : 1.5;
    var pitchX = Math.sqrt(3) * r + gap;
    var pitchY = 1.5 * r + gap * 0.87;
    var cols = Math.floor((w - pitchX / 2 + gap) / pitchX);
    var rows = Math.floor((h - 2 * r) / pitchY) + 1;
    return { r: r, pitchX: pitchX, pitchY: pitchY, cols: Math.max(cols, 0), rows: Math.max(rows, 0) };
  }

  function gridLayout(n, w, h) {
    for (var r = 24; r >= 3.5; r -= 0.5) {
      var g = hexGrid(r, w, h);
      if (g.cols > 0 && g.cols * g.rows >= n) {
        g.per = 1;
        g.cells = n;
        return g;
      }
    }
    var small = hexGrid(3.5, w, h);
    small.cols = Math.max(small.cols, 1);
    small.rows = Math.max(small.rows, 1);
    small.per = Math.ceil(n / (small.cols * small.rows));
    small.cells = Math.ceil(n / small.per);
    return small;
  }

  // The card renders with the cells of its first tick. A later message of
  // the same run is newer.
  function nameCells(grid) {
    var msg = names.msg;
    if (msg && msg.run_id === grid.getAttribute("data-run")) return msg.cells || "";
    return grid.getAttribute("data-cells") || "";
  }

  function drawNames(now) {
    names.raf = 0;
    var grid = document.querySelector(".vn-run-card .vn-run-grid");
    if (!grid) return;
    var area = grid.querySelector(".vn-run-grid-area");
    var fit = fitCanvas(area.querySelector("canvas"), area);
    if (!fit) return;
    var ctx = fit.ctx;
    var cells = nameCells(grid);
    var n = cells.length;
    var L = gridLayout(n, fit.w, fit.h);
    var rows = Math.ceil(L.cells / L.cols);
    var usedCols = Math.min(L.cols, L.cells);
    var gridW = (usedCols - 1) * L.pitchX + Math.sqrt(3) * L.r + (rows > 1 ? L.pitchX / 2 : 0);
    var gridH = (rows - 1) * L.pitchY + 2 * L.r;
    var ox = (fit.w - gridW) / 2 + Math.sqrt(3) * L.r / 2;
    var oy = (fit.h - gridH) / 2 + L.r;
    var colors = {};
    Object.keys(NAME_COLORS).forEach(function (k) { colors[k] = token(NAME_COLORS[k]); });
    var accent = token("--accent-fill");
    var empty = token("--border-strong");
    var still = reducedMotion();
    var pulse = still ? 0.55 : 0.35 + 0.35 * Math.sin((now || 0) / 140);
    var queued = false;

    for (var k = 0; k < L.cells; k++) {
      var row = Math.floor(k / L.cols);
      var x = ox + (k % L.cols) * L.pitchX + (row % 2 ? L.pitchX / 2 : 0);
      var y = oy + row * L.pitchY;
      var tally = { a: 0, s: 0, m: 0, n: 0 };
      var done = 0;
      var inQueue = false;
      var last = Math.min(n, (k + 1) * L.per);
      for (var i = k * L.per; i < last; i++) {
        var c = cells.charAt(i);
        if (tally[c] !== undefined) { tally[c]++; done++; }
        else if (c === "q") inQueue = true;
      }
      ctx.beginPath();
      hexPath(ctx, x, y, L.r);
      if (done) {
        // A cell of several names takes the most common answer, and its
        // fill shows how many names of the cell have one.
        var top = "a";
        Object.keys(tally).forEach(function (key) { if (tally[key] > tally[top]) top = key; });
        ctx.fillStyle = colors[top];
        ctx.globalAlpha = L.per > 1 ? 0.35 + 0.65 * done / (last - k * L.per) : 1;
        ctx.fill();
      } else if (inQueue) {
        queued = true;
        ctx.fillStyle = accent;
        ctx.globalAlpha = pulse;
        ctx.fill();
      } else {
        ctx.strokeStyle = empty;
        ctx.lineWidth = 1;
        ctx.setLineDash(L.r >= 8 ? [3, 3] : []);
        ctx.stroke();
        ctx.setLineDash([]);
      }
      ctx.globalAlpha = 1;
    }

    var perNote = grid.querySelector(".vn-run-grid-per");
    perNote.textContent = L.per > 1 ? (grid.getAttribute("data-per") || "").replace("%s", L.per) : "";
    if (queued && !still) scheduleNames();
  }

  function scheduleNames() {
    if (!names.raf) names.raf = window.requestAnimationFrame(drawNames);
  }

  function updateNameCard(msg) {
    var card = document.querySelector(".vn-run-card");
    if (!card) return;
    card.querySelector(".vn-run-eyebrow").textContent = msg.eyebrow;
    card.querySelector(".vn-run-count").textContent = msg.count;
    card.querySelector(".vn-run-bar").classList.toggle("is-waiting", !!msg.waiting);
    card.querySelector(".vn-run-bar-fill").style.width = msg.pct + "%";
    (msg.steps || []).forEach(function (step) {
      var row = card.querySelector('.vn-run-step[data-step="' + step.key + '"]');
      if (!row) return;
      row.className = "vn-run-step is-" + step.state;
      row.querySelector(".vn-run-step-label").textContent = step.label;
      row.querySelector(".vn-run-step-state").textContent = step.state_label;
    });
    card.querySelectorAll(".vn-run-legend-item").forEach(function (item) {
      var value = msg.tally && msg.tally[item.getAttribute("data-code")];
      if (value !== undefined) item.querySelector("b").textContent = value;
    });
  }

  /* ---------------- Names: the answer list ---------------- */

  // During a run the server sends the rows of the list with a key per name.
  // A row changes only when its HTML changes, and the list stays in the
  // page, so the scroll and the focus stay too (DEP-07).
  function rowFromHtml(html) {
    var tpl = document.createElement("template");
    tpl.innerHTML = html;
    var row = tpl.content.firstElementChild;
    row.vnHtml = html;
    return row;
  }

  function syncStream(msg) {
    var panel = document.getElementById(msg.id);
    if (!panel) return;
    Object.keys(msg.counts || {}).forEach(function (key) {
      var pill = document.getElementById(msg.pill_prefix + key);
      var count = pill && pill.querySelector(".vn-pill-count");
      var text = String(msg.counts[key]);
      if (count && count.textContent !== text) count.textContent = text;
    });
    var body = panel.querySelector(".vn-stream-body");
    if (!body) return;
    var rows = msg.rows || [];
    var list = body.querySelector(":scope > .vn-stream-list");
    if (!rows.length) {
      if (list || body.vnEmpty !== msg.empty) {
        body.innerHTML = msg.empty;
        body.vnEmpty = msg.empty;
      }
      return;
    }
    if (!list) {
      body.innerHTML = "";
      body.vnEmpty = null;
      list = document.createElement("div");
      list.className = "vn-stream-list";
      body.appendChild(list);
    }
    // New rows go on top. Keep the rows the user reads where they are.
    var heightBefore = body.scrollTop > 0 ? list.scrollHeight : null;
    var old = {};
    Array.prototype.forEach.call(list.children, function (el) {
      old[el.getAttribute("data-key")] = el;
    });
    var prev = null;
    rows.forEach(function (row) {
      var el = Object.prototype.hasOwnProperty.call(old, row.key) ? old[row.key] : null;
      if (el) delete old[row.key];
      if (!el || el.vnHtml !== row.html) {
        var fresh = rowFromHtml(row.html);
        if (el) list.replaceChild(fresh, el);
        el = fresh;
      }
      var next = prev ? prev.nextElementSibling : list.firstElementChild;
      if (el !== next) list.insertBefore(el, next);
      prev = el;
    });
    Object.keys(old).forEach(function (key) { old[key].remove(); });
    if (heightBefore !== null) body.scrollTop += list.scrollHeight - heightBefore;
  }

  /* ---------------- Steps of a run card ---------------- */

  // The Coordinates stage builds its step rows once, then changes them in
  // place: a rebuilt list makes a screen reader read every step again. The
  // labels come from the server, so textContent keeps them as text.
  function paintRunBody(body, p) {
    if (!body || !p) return;
    body.querySelector(".vn-run-eyebrow").textContent = p.eyebrow;
    body.querySelector(".vn-run-count").textContent = p.count;
    body.querySelector(".vn-run-bar-fill").style.width = p.pct + "%";
    var list = body.querySelector(".vn-run-steps");
    (p.steps || []).forEach(function (step) {
      var row = list.querySelector('.vn-run-step[data-step="' + step.key + '"]');
      if (!row) {
        row = document.createElement("div");
        row.setAttribute("data-step", step.key);
        ["vn-run-step-dot", "vn-run-step-label", "vn-run-step-state"].forEach(function (cls) {
          var span = document.createElement("span");
          span.className = cls;
          if (cls === "vn-run-step-dot") span.setAttribute("aria-hidden", "true");
          row.appendChild(span);
        });
        list.appendChild(row);
      }
      row.className = "vn-run-step is-" + step.state + (step.hit ? " is-hit" : "");
      row.querySelector(".vn-run-step-label").textContent = step.label;
      row.querySelector(".vn-run-step-state").textContent = step.state_label;
    });
  }

  /* ---------------- Coordinates: radar over the points ---------------- */

  var FAMILY_COLORS = { validity: "--error-fill", sea: "--info-fill", zero_equal: "--warning", reference: "--coord-swapped" };
  var SWEEP_MS = 2400;
  var TRAIL = 0.22;
  var TRAIL_HEX = 5;
  var POP_MS = 700;
  var HOLD_MS = 600;
  var FADE_MS = 400;
  var REVEAL_MS = 700;
  var coords = null;

  function asArray(x) {
    return x === null || x === undefined ? [] : [].concat(x);
  }

  // The view fits the points with a margin and at least 4 degrees, then
  // widens one axis to the shape of the canvas.
  function makeProjection(view, w, h) {
    var lon = view.lon;
    var lat = view.lat;
    if (!lon.length) return null;
    var x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
    for (var i = 0; i < lon.length; i++) {
      if (lon[i] < x0) x0 = lon[i];
      if (lon[i] > x1) x1 = lon[i];
      if (lat[i] < y0) y0 = lat[i];
      if (lat[i] > y1) y1 = lat[i];
    }
    var cx = (x0 + x1) / 2;
    var cy = (y0 + y1) / 2;
    var kx = Math.cos(cy * Math.PI / 180);
    var sx = Math.max(4, (x1 - x0) * 1.16) * kx;
    var sy = Math.max(4, (y1 - y0) * 1.16);
    if (sx / sy < w / h) sx = sy * w / h; else sy = sx * h / w;
    var scale = w / sx;
    return function (lo, la) {
      return [(lo - cx) * kx * scale + w / 2, h / 2 - (la - cy) * scale];
    };
  }

  // Land and the dim points do not move, so they are drawn once per size
  // and theme into an offscreen layer.
  function ensureLayer(fit) {
    var key = fit.w + "x" + fit.h + "|" + token("--bg-card");
    if (coords.layerKey === key) return;
    coords.layerKey = key;
    var P = makeProjection(coords.view, fit.w, fit.h);
    coords.project = P;
    var dpr = window.devicePixelRatio || 1;
    var layer = coords.layer || document.createElement("canvas");
    layer.width = Math.round(fit.w * dpr);
    layer.height = Math.round(fit.h * dpr);
    var g = layer.getContext("2d");
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, fit.w, fit.h);
    coords.layer = layer;
    if (!P) return;

    g.fillStyle = token("--border-light");
    g.beginPath();
    coords.view.land.forEach(function (ring) {
      ring = asArray(ring);
      for (var i = 0; i + 1 < ring.length; i += 2) {
        var xy = P(ring[i], ring[i + 1]);
        if (i === 0) g.moveTo(xy[0], xy[1]); else g.lineTo(xy[0], xy[1]);
      }
      g.closePath();
    });
    g.fill("evenodd");

    var n = coords.view.lon.length;
    var dot = n > 5000 ? 1.6 : 2.5;
    var pts = [];
    g.fillStyle = token("--text-muted");
    g.globalAlpha = 0.35;
    g.beginPath();
    for (var k = 0; k < n; k++) {
      var p = P(coords.view.lon[k], coords.view.lat[k]);
      pts.push(p);
      hexPath(g, p[0], p[1], dot);
    }
    g.fill();
    g.globalAlpha = 1;
    // Sorted by x, so a frame finds the points under the trail fast.
    pts.sort(function (a, b) { return a[0] - b[0]; });
    coords.pts = pts;
    coords.dot = dot;
    coords.flags.forEach(function (f) { f.xy = P(f.lon, f.lat); });
  }

  function firstAtOrAfter(pts, x) {
    var lo = 0, hi = pts.length;
    while (lo < hi) {
      var mid = (lo + hi) >> 1;
      if (pts[mid][0] < x) lo = mid + 1; else hi = mid;
    }
    return lo;
  }

  // The trail is a band of small hexagons that fades behind the line. The
  // honeycomb is fixed to the canvas, so the line lights it up as it moves.
  function drawHexTrail(ctx, lx, trail, h, color) {
    var pitchX = Math.sqrt(3) * TRAIL_HEX + 1;
    var pitchY = 1.5 * TRAIL_HEX + 0.87;
    var rows = Math.ceil(h / pitchY) + 1;
    ctx.fillStyle = color;
    for (var odd = 0; odd < 2; odd++) {
      var shift = odd ? pitchX / 2 : 0;
      var c0 = Math.max(0, Math.floor((lx - trail - shift) / pitchX));
      var c1 = Math.floor((lx - shift) / pitchX);
      for (var c = c0; c <= c1; c++) {
        var x = c * pitchX + shift;
        var d = lx - x;
        if (d < 0 || d > trail) continue;
        ctx.globalAlpha = 0.3 * (1 - d / trail);
        ctx.beginPath();
        for (var r = odd; r < rows; r += 2) hexPath(ctx, x, r * pitchY, TRAIL_HEX);
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;
  }

  function drawCoords(now) {
    if (!coords) return;
    coords.raf = 0;
    var canvas = coords.stage.querySelector("canvas");
    var fit = fitCanvas(canvas, canvas.parentElement);
    if (!fit) return;
    var ctx = fit.ctx;
    var still = reducedMotion();
    var active = false;
    if (coords.view) {
      ensureLayer(fit);
      ctx.drawImage(coords.layer, 0, 0, fit.w, fit.h);
    }
    var accent = token("--accent-fill");
    var sweeping = !!coords.project && !coords.ending && !still;
    var trail = fit.w * TRAIL;
    var lx = sweeping ? ((now - coords.t0) % SWEEP_MS) / SWEEP_MS * fit.w : -1;
    if (sweeping) {
      active = true;
      drawHexTrail(ctx, lx, trail, fit.h, accent);
      ctx.fillStyle = accent;
      for (var i = firstAtOrAfter(coords.pts, lx - trail); i < coords.pts.length && coords.pts[i][0] <= lx; i++) {
        var p = coords.pts[i];
        var glow = 1 - (lx - p[0]) / trail;
        ctx.globalAlpha = 0.3 + 0.6 * glow;
        ctx.beginPath();
        hexPath(ctx, p[0], p[1], coords.dot + glow * 1.8);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    }
    coords.flags.forEach(function (f) {
      if (!f.xy || (!still && now < f.revealAt)) return;
      var color = token(FAMILY_COLORS[f.family] || "--error-fill");
      ctx.fillStyle = color;
      ctx.beginPath();
      hexPath(ctx, f.xy[0], f.xy[1], 5);
      ctx.fill();
      var age = now - f.revealAt;
      if (!still && age < POP_MS) {
        active = true;
        var a = 1 - age / POP_MS;
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.globalAlpha = a;
        ctx.beginPath();
        hexPath(ctx, f.xy[0], f.xy[1], 7 + 11 * (1 - a));
        ctx.stroke();
        ctx.globalAlpha = 1;
      }
    });
    if (sweeping) {
      ctx.strokeStyle = accent;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(lx, 0);
      ctx.lineTo(lx, fit.h);
      ctx.stroke();
    }
    if (active || (coords.flags.length && !still && coords.flags.some(function (f) { return now < f.revealAt; }))) {
      scheduleCoords();
    }
  }

  function scheduleCoords() {
    if (coords && !coords.raf) coords.raf = window.requestAnimationFrame(drawCoords);
  }

  function hideCoordsStage() {
    if (!coords) return;
    if (coords.raf) window.cancelAnimationFrame(coords.raf);
    if (coords.timer) window.clearTimeout(coords.timer);
    coords.stage.hidden = true;
    coords.stage.classList.remove("is-leaving");
    coords.layout.classList.remove("is-coords-running");
    coords = null;
  }

  // The results come in after the stage is gone, one block after the
  // other. A crossfade of two different layouts looks abrupt.
  function revealResults(layout) {
    if (reducedMotion()) return;
    layout.classList.add("is-revealing");
    window.setTimeout(function () { layout.classList.remove("is-revealing"); }, REVEAL_MS);
  }

  function coordsStart(msg) {
    var stage = document.getElementById(msg.id);
    if (!stage) return;
    hideCoordsStage();
    coords = {
      stage: stage, layout: stage.parentElement, view: null, project: null,
      layer: null, layerKey: null, pts: [], dot: 2.2, flags: [],
      t0: performance.now(), raf: 0, timer: 0, ending: false
    };
    stage.hidden = false;
    coords.layout.classList.add("is-coords-running");
    coordsProgress(msg.progress);
    scheduleCoords();
  }

  function coordsProgress(p) {
    if (!coords || !p) return;
    paintRunBody(coords.stage.querySelector(".vn-run-body"), p);
    coords.stage.querySelector("canvas").setAttribute("aria-label", p.map_label);
  }

  // A flag appears when the line next passes over it.
  function coordsFlags(family, flat) {
    var now = performance.now();
    var phase = ((now - coords.t0) % SWEEP_MS) / SWEEP_MS;
    var w = coords.stage.querySelector("canvas").parentElement.clientWidth || 1;
    for (var i = 0; i + 1 < flat.length; i += 2) {
      var f = { family: family, lon: flat[i], lat: flat[i + 1], revealAt: now, xy: null };
      if (coords.project) {
        f.xy = coords.project(f.lon, f.lat);
        f.revealAt = now + ((f.xy[0] / w - phase + 1) % 1) * SWEEP_MS;
      }
      coords.flags.push(f);
    }
  }

  function settleCoords() {
    coords.ending = true;
    var now = performance.now();
    coords.flags.forEach(function (f) { if (f.revealAt > now) f.revealAt = now; });
    scheduleCoords();
  }

  function coordsEnd(msg) {
    if (!coords) return;
    if (msg.failed) {
      hideCoordsStage();
      return;
    }
    // Hold the result, then the stage fades out and the results come in.
    settleCoords();
    var still = reducedMotion();
    coords.timer = window.setTimeout(function () {
      if (!coords) return;
      coords.stage.classList.add("is-leaving");
      coords.timer = window.setTimeout(function () {
        var layout = coords && coords.layout;
        hideCoordsStage();
        if (layout) revealResults(layout);
      }, still ? 0 : FADE_MS);
    }, still ? 300 : HOLD_MS);
  }

  function onCoordsRun(msg) {
    if (msg.stage === "start") { coordsStart(msg); return; }
    if (!coords) return;
    if (msg.stage === "map") {
      coords.view = {
        lon: asArray(msg.view && msg.view.lon),
        lat: asArray(msg.view && msg.view.lat),
        land: asArray(msg.view && msg.view.land)
      };
      coords.layerKey = null;
    }
    if (msg.stage === "step" && msg.family) coordsFlags(msg.family, asArray(msg.flags));
    if (msg.stage === "end") { coordsEnd(msg); return; }
    // The last test is done. Stop the line and show every flag now, because
    // the page still needs a moment to build the result.
    if (msg.progress && msg.progress.done) settleCoords();
    coordsProgress(msg.progress);
    scheduleCoords();
  }

  /* ---------------- Wiring ---------------- */

  // A hidden canvas has no size and stops its frames. Draw again when the
  // window or the tab shows it.
  function redrawAll() {
    scheduleNames();
    scheduleCoords();
  }

  window.addEventListener("resize", redrawAll);
  $(document).on("shown.bs.tab", redrawAll);

  $(function () {
    Shiny.addCustomMessageHandler("coordsRun", onCoordsRun);
    Shiny.addCustomMessageHandler("vnStreamSync", syncStream);

    Shiny.addCustomMessageHandler("vnRunProgress", function (msg) {
      names.msg = msg;
      updateNameCard(msg);
      scheduleNames();
    });

    // The card arrives in a renderUI value. Draw after Shiny puts it in
    // the page.
    $(document).on("shiny:value", function (e) {
      if (/report_panel$/.test(e.name)) window.setTimeout(scheduleNames, 0);
    });
  });
})();

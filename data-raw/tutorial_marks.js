// Annotation layer for the tutorial screenshots. The shot script injects this
// file into the running app, draws marks over real elements, then captures
// the #tut-clip region. Marks live in one absolutely positioned layer, so the
// app layout never moves.
window.tutMarks = (function () {
  var NS = 'http://www.w3.org/2000/svg';
  var opts = { color: '#e0157a', style: 'box' };

  function layer() {
    var h = document.getElementById('tut-layer');
    if (!h) {
      h = document.createElement('div');
      h.id = 'tut-layer';
      h.style.cssText = 'position:absolute;left:0;top:0;width:0;height:0;' +
        'z-index:2147483000;pointer-events:none;';
      document.body.appendChild(h);
      var st = document.createElement('style');
      st.id = 'tut-style';
      st.textContent =
        '#shiny-notification-panel{display:none!important}' +
        '*{caret-color:transparent!important}' +
        // A scrollbar that vanishes during the capture would shift the layout
        // under marks that were already drawn.
        'html{scrollbar-width:none!important}::-webkit-scrollbar{display:none!important}' +
        '.tut-badge{position:absolute;width:28px;height:28px;border-radius:50%;' +
        'display:flex;align-items:center;justify-content:center;color:#fff;' +
        'font:700 14px/1 "Space Mono",monospace;box-shadow:0 0 0 3px #fff;}' +
        '.tut-box{position:absolute;border:3px solid;border-radius:12px;}' +
        '.tut-label{position:absolute;color:#fff;padding:5px 11px;border-radius:8px;' +
        'font:700 13px/1.25 "Space Mono",monospace;white-space:nowrap;box-shadow:0 0 0 3px #fff;}';
      document.head.appendChild(st);
    }
    return h;
  }

  function el(sel) {
    var e = typeof sel === 'string' ? document.querySelector(sel) : sel;
    if (!e) throw new Error('tutMarks: no element for ' + sel);
    return e;
  }

  // fit: wrap the visible children, not a container that fills the row.
  function rect(sel, pad, fit) {
    var e = el(sel), r = e.getBoundingClientRect();
    if (fit) {
      var l = Infinity, t = Infinity, rr = -Infinity, b = -Infinity;
      Array.prototype.forEach.call(e.children, function (k) {
        var q = k.getBoundingClientRect();
        if (q.width < 2 || q.height < 2) return;
        l = Math.min(l, q.left); t = Math.min(t, q.top);
        rr = Math.max(rr, q.right); b = Math.max(b, q.bottom);
      });
      if (l < Infinity) r = { left: l, top: t, width: rr - l, height: b - t };
    }
    pad = pad || 0;
    return { x: r.left + window.scrollX - pad, y: r.top + window.scrollY - pad,
             w: r.width + 2 * pad, h: r.height + 2 * pad };
  }

  function div(cls, css) {
    var d = document.createElement('div');
    d.className = cls;
    d.style.cssText = css;
    layer().appendChild(d);
    return d;
  }

  function box(sel, o) {
    o = o || {};
    var r = rect(sel, o.pad == null ? 6 : o.pad, o.fit);
    div('tut-box', 'left:' + r.x + 'px;top:' + r.y + 'px;width:' + r.w + 'px;height:' +
      r.h + 'px;border-color:' + opts.color + ';border-radius:' + (o.radius || 12) + 'px;');
    return r;
  }

  // corner: ol (outside left, the default), or (outside right), ot (above the
  // top-right corner, clear of a left-aligned title), or a point of the
  // padded box: tl, tr, bl, br. The outside
  // corners keep the badge off the text that the box marks.
  function badge(sel, n, o) {
    o = o || {};
    var r = rect(sel, o.pad == null ? 6 : o.pad, o.fit);
    var c = o.corner || 'ol', x, y;
    if (c === 'ol') { x = r.x - 19; y = r.y + r.h / 2; }
    else if (c === 'or') { x = r.x + r.w + 19; y = r.y + r.h / 2; }
    else if (c === 'ot') { x = r.x + r.w - 14; y = r.y - 17; }
    else {
      x = c[1] === 'r' ? r.x + r.w : r.x;
      y = c[0] === 'b' ? r.y + r.h : r.y;
    }
    var b = div('tut-badge', 'left:' + (x - 14 + (o.dx || 0)) + 'px;top:' + (y - 14 + (o.dy || 0)) +
      'px;background:' + opts.color + ';');
    b.textContent = n;
  }

  // Box plus badge, the usual pair.
  function mark(sel, n, o) {
    o = o || {};
    box(sel, { pad: o.pad == null ? 4 : o.pad, radius: o.radius || 10, fit: o.fit });
    badge(sel, n, { pad: o.pad == null ? 4 : o.pad, fit: o.fit, corner: o.corner, dx: o.dx, dy: o.dy });
  }

  // Short curved arrow that ends on one side of the element.
  function arrow(sel, o) {
    o = o || {};
    var r = rect(sel, o.pad == null ? 8 : o.pad);
    var side = o.side || 'left', len = o.len || 70;
    var tx, ty, sx, sy;
    if (side === 'left') { tx = r.x; ty = r.y + r.h / 2; sx = tx - len; sy = ty + len * 0.45; }
    if (side === 'right') { tx = r.x + r.w; ty = r.y + r.h / 2; sx = tx + len; sy = ty + len * 0.45; }
    if (side === 'top') { tx = r.x + r.w / 2; ty = r.y; sx = tx - len * 0.45; sy = ty - len; }
    if (side === 'bottom') { tx = r.x + r.w / 2; ty = r.y + r.h; sx = tx - len * 0.45; sy = ty + len; }
    var minx = Math.min(sx, tx) - 20, miny = Math.min(sy, ty) - 20;
    var w = Math.abs(sx - tx) + 40, h = Math.abs(sy - ty) + 40;
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('width', w); svg.setAttribute('height', h);
    svg.style.cssText = 'position:absolute;left:' + minx + 'px;top:' + miny + 'px;overflow:visible;';
    var a = [sx - minx, sy - miny], t = [tx - minx, ty - miny];
    var cx = side === 'left' || side === 'right' ? a[0] : t[0];
    var cy = side === 'left' || side === 'right' ? t[1] : a[1];
    var p = document.createElementNS(NS, 'path');
    p.setAttribute('d', 'M' + a + ' Q' + cx + ',' + cy + ' ' + t);
    p.setAttribute('fill', 'none'); p.setAttribute('stroke', opts.color);
    p.setAttribute('stroke-width', '4'); p.setAttribute('stroke-linecap', 'round');
    svg.appendChild(p);
    var ang = Math.atan2(t[1] - cy, t[0] - cx), hl = 14;
    var head = document.createElementNS(NS, 'path');
    head.setAttribute('d', 'M' + (t[0] - hl * Math.cos(ang - 0.5)) + ',' + (t[1] - hl * Math.sin(ang - 0.5)) +
      ' L' + t + ' L' + (t[0] - hl * Math.cos(ang + 0.5)) + ',' + (t[1] - hl * Math.sin(ang + 0.5)));
    head.setAttribute('fill', 'none'); head.setAttribute('stroke', opts.color);
    head.setAttribute('stroke-width', '4'); head.setAttribute('stroke-linecap', 'round');
    head.setAttribute('stroke-linejoin', 'round');
    svg.appendChild(head);
    layer().appendChild(svg);
    return { x: sx, y: sy };
  }

  function label(sel, text, o) {
    o = o || {};
    var tip = arrow(sel, o);
    var d = div('tut-label', 'background:' + opts.color + ';');
    d.textContent = text;
    var lw = d.offsetWidth, lh = d.offsetHeight;
    var side = o.side || 'left';
    var lx = side === 'right' ? tip.x + 4 : side === 'left' ? tip.x - lw - 4 : tip.x - lw / 2;
    var ly = side === 'top' ? tip.y - lh - 4 : side === 'bottom' ? tip.y + 4 : tip.y - lh / 2;
    d.style.left = lx + 'px'; d.style.top = ly + 'px';
  }

  // Dim everything except the given elements (one SVG mask, several holes).
  function spotlight(sels, o) {
    o = o || {};
    var W = document.documentElement.scrollWidth, H = document.documentElement.scrollHeight;
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('width', W); svg.setAttribute('height', H);
    svg.style.cssText = 'position:absolute;left:0;top:0;';
    var id = 'tut-mask-' + Math.random().toString(36).slice(2);
    var defs = document.createElementNS(NS, 'defs');
    var mask = document.createElementNS(NS, 'mask'); mask.setAttribute('id', id);
    var full = document.createElementNS(NS, 'rect');
    full.setAttribute('width', W); full.setAttribute('height', H); full.setAttribute('fill', '#fff');
    mask.appendChild(full);
    sels.forEach(function (s) {
      var r = rect(s, o.pad == null ? 8 : o.pad);
      var hole = document.createElementNS(NS, 'rect');
      hole.setAttribute('x', r.x); hole.setAttribute('y', r.y);
      hole.setAttribute('width', r.w); hole.setAttribute('height', r.h);
      hole.setAttribute('rx', 12); hole.setAttribute('fill', '#000');
      mask.appendChild(hole);
    });
    defs.appendChild(mask); svg.appendChild(defs);
    // A gray shade does not show on the dark theme, so use a deeper black
    // there and outline each hole.
    var bg = getComputedStyle(document.body).backgroundColor.match(/\d+/g).map(Number);
    var dark = (0.2126 * bg[0] + 0.7152 * bg[1] + 0.0722 * bg[2]) < 90;
    var shade = document.createElementNS(NS, 'rect');
    shade.setAttribute('width', W); shade.setAttribute('height', H);
    shade.setAttribute('fill', dark ? 'rgba(0,0,0,' + (o.alpha || 0.62) + ')'
                                    : 'rgba(28,28,38,' + (o.alpha || 0.5) + ')');
    shade.setAttribute('mask', 'url(#' + id + ')');
    svg.appendChild(shade);
    if (dark) {
      sels.forEach(function (s) {
        var r = rect(s, o.pad == null ? 8 : o.pad);
        var ring = document.createElementNS(NS, 'rect');
        ring.setAttribute('x', r.x); ring.setAttribute('y', r.y);
        ring.setAttribute('width', r.w); ring.setAttribute('height', r.h);
        ring.setAttribute('rx', 12); ring.setAttribute('fill', 'none');
        ring.setAttribute('stroke', 'rgba(255,255,255,0.55)'); ring.setAttribute('stroke-width', 1.5);
        svg.appendChild(ring);
      });
    }
    layer().insertBefore(svg, layer().firstChild);
  }

  // The capture region: the union of the given elements plus padding.
  function clip(sels, pad) {
    pad = pad == null ? 24 : pad;
    var x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity;
    sels.forEach(function (s) {
      var r = rect(s, pad);
      x1 = Math.min(x1, r.x); y1 = Math.min(y1, r.y);
      x2 = Math.max(x2, r.x + r.w); y2 = Math.max(y2, r.y + r.h);
    });
    x1 = Math.max(0, x1); y1 = Math.max(0, y1);
    x2 = Math.min(document.documentElement.scrollWidth, x2);
    var old = document.getElementById('tut-clip');
    if (old) old.remove();
    var c = div('', 'left:' + x1 + 'px;top:' + y1 + 'px;width:' + (x2 - x1) + 'px;height:' +
      (y2 - y1) + 'px;position:absolute;');
    c.id = 'tut-clip';
    return [x1, y1, x2 - x1, y2 - y1];
  }

  function clear() {
    var h = layer();
    Array.prototype.slice.call(h.childNodes).forEach(function (n) { n.remove(); });
  }

  // Give an id to the first leaf under root whose text starts with prefix, so
  // marks can target text that has no selector of its own.
  function tag(root, prefix, id) {
    var all = el(root).querySelectorAll('*');
    for (var i = 0; i < all.length; i++) {
      var n = all[i];
      if (n.children.length === 0 && n.textContent.trim().indexOf(prefix) === 0) {
        n.id = id;
        return true;
      }
    }
    throw new Error('tutMarks: no text ' + prefix + ' in ' + root);
  }

  // Give an id to the closest ancestor of sel that matches anc.
  function up(sel, anc, id) {
    var n = el(sel).closest(anc);
    if (!n) throw new Error('tutMarks: no ' + anc + ' above ' + sel);
    n.id = id;
    return true;
  }

  function set(o) { for (var k in o) opts[k] = o[k]; }

  return { box: box, badge: badge, mark: mark, arrow: arrow, label: label, spotlight: spotlight,
           clip: clip, clear: clear, set: set, rect: rect, tag: tag, up: up };
})();

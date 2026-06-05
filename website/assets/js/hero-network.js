/* =============================================================================
   Saíra — hero: rede de "nós de ocorrência"
   Portado de index.html (versão original) e adaptado para:
   - rodar dentro do hero (.hero > canvas#hero-canvas), dimensionado ao container;
   - funcionar nos temas claro e escuro (limpa o frame; lê --text para os rótulos);
   - respeitar prefers-reduced-motion (desenha um quadro estático, sem loop).
   Paleta de táxons = cores da Tangara fastuosa + biomas do Brasil.
   ============================================================================= */
(function () {
  var canvas = document.getElementById('hero-canvas');
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  var hero = canvas.closest('.hero') || canvas.parentElement;
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var width = 0, height = 0, time = 0, nodes = [];
  var dpr = Math.min(window.devicePixelRatio || 1, 2);

  var sairaTaxonomies = [
    { name: "Animalia",  color: "#38CFF6" },
    { name: "Plantae",   color: "#00A86B" },
    { name: "Fungi",     color: "#FFA204" },
    { name: "Chromista", color: "#16B3BD" },
    { name: "Protozoa",  color: "#2833AC" },
    { name: "Bacteria",  color: "#252659" },
    { name: "Archaea",   color: "#0E8A95" }
  ];
  var brazilTaxonomies = [
    { name: "Amazônia",  color: "#009B3A" },
    { name: "Cerrado",   color: "#C9A227" },
    { name: "Pantanal",  color: "#3B5BA9" },
    { name: "Caatinga",  color: "#C76B3A" }
  ];

  var MOUSE_RADIUS = 220;
  var CONNECTION_DIST = 150;
  var mouse = { x: -9999, y: -9999 };

  function cssVar(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }
  function textColor() { return cssVar('--text') || '#1C1C26'; }

  function nodeCount() {
    return Math.max(40, Math.min(120, Math.round(width * height / 13000)));
  }

  function OccurrenceNode(index, total) {
    this.x = Math.random() * width;
    this.y = Math.random() * height;
    this.vx = (Math.random() - 0.5) * 0.28;
    this.vy = (Math.random() - 0.5) * 0.28;
    this.taxon = (index < total * 0.6)
      ? sairaTaxonomies[index % sairaTaxonomies.length]
      : brazilTaxonomies[index % brazilTaxonomies.length];
    this.lat = (Math.random() * 30 - 33).toFixed(3);
    this.lon = (Math.random() * 28 - 70).toFixed(3);
    this.radius = Math.random() * 1.8 + 1.4;
    this.phase = Math.random() * Math.PI * 2;
  }
  OccurrenceNode.prototype.update = function () {
    this.x += this.vx; this.y += this.vy;
    if (this.x < 0) this.x = width; else if (this.x > width) this.x = 0;
    if (this.y < 0) this.y = height; else if (this.y > height) this.y = 0;
  };
  OccurrenceNode.prototype.draw = function (distToMouse, label) {
    var pulse = Math.sin(time * 0.02 + this.phase) * 0.5 + 0.5;
    var r = this.radius + pulse * 1.4;
    var opacity = 0.32;

    if (distToMouse < MOUSE_RADIUS) {
      var intensity = 1 - distToMouse / MOUSE_RADIUS;
      opacity = 0.32 + intensity * 0.68;
      if (label && distToMouse < MOUSE_RADIUS * 0.5) {
        ctx.font = "11px 'Space Mono', monospace";
        ctx.globalAlpha = intensity;
        ctx.fillStyle = textColor();
        var text = pulse > 0.5 ? this.taxon.name : "[" + this.lat + ", " + this.lon + "]";
        ctx.fillText(text, this.x + 9, this.y + 4);
        ctx.globalAlpha = 1;
      }
    }
    ctx.beginPath();
    ctx.arc(this.x, this.y, r, 0, Math.PI * 2);
    ctx.fillStyle = this.taxon.color;
    ctx.globalAlpha = opacity;
    ctx.fill();
    ctx.globalAlpha = 1;
  };

  function build() {
    var total = nodeCount();
    nodes = [];
    for (var i = 0; i < total; i++) nodes.push(new OccurrenceNode(i, total));
  }

  function resize() {
    var rect = hero.getBoundingClientRect();
    width = Math.max(1, rect.width);
    height = Math.max(1, rect.height);
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    build();
  }

  function frame(interactive) {
    ctx.clearRect(0, 0, width, height);
    var lineCol = cssVar('--dots-line') || 'rgba(56,207,246,0.30)';

    for (var i = 0; i < nodes.length; i++) {
      var n1 = nodes[i];
      var dm1 = Math.hypot(mouse.x - n1.x, mouse.y - n1.y);
      for (var j = i + 1; j < nodes.length; j++) {
        var n2 = nodes[j];
        var dx = n1.x - n2.x, dy = n1.y - n2.y;
        var dist = Math.sqrt(dx * dx + dy * dy);
        var maxDist = (n1.taxon.name === n2.taxon.name) ? CONNECTION_DIST * 1.5 : CONNECTION_DIST;
        var dm2 = Math.hypot(mouse.x - n2.x, mouse.y - n2.y);
        var near = !interactive || dm1 < MOUSE_RADIUS || dm2 < MOUSE_RADIUS;
        if (dist < maxDist && near) {
          var op = (1 - dist / maxDist) * (interactive ? 0.4 : 0.22);
          var midX = (n1.x + n2.x) / 2, midY = (n1.y + n2.y) / 2;
          var off = Math.sin(time * 0.01 + n1.phase) * 16;
          var cpX = midX + (dy / dist) * off;
          var cpY = midY - (dx / dist) * off;
          ctx.beginPath();
          ctx.moveTo(n1.x, n1.y);
          ctx.quadraticCurveTo(cpX, cpY, n2.x, n2.y);
          if (n1.taxon.name === n2.taxon.name) {
            ctx.strokeStyle = n1.taxon.color; ctx.globalAlpha = op * 1.4;
          } else {
            ctx.strokeStyle = lineCol; ctx.globalAlpha = op;
          }
          ctx.lineWidth = 1;
          ctx.stroke();
          ctx.globalAlpha = 1;
        }
      }
    }

    for (var k = 0; k < nodes.length; k++) {
      var n = nodes[k];
      var d = Math.hypot(mouse.x - n.x, mouse.y - n.y);
      if (interactive && d < MOUSE_RADIUS * 0.5) {
        n.x -= ((mouse.x - n.x) / d) * 0.5;
        n.y -= ((mouse.y - n.y) / d) * 0.5;
      }
      n.draw(d, interactive);
    }
  }

  function animate() {
    time++;
    for (var i = 0; i < nodes.length; i++) nodes[i].update();
    frame(true);
    requestAnimationFrame(animate);
  }

  hero.addEventListener('mousemove', function (e) {
    var rect = canvas.getBoundingClientRect();
    mouse.x = e.clientX - rect.left;
    mouse.y = e.clientY - rect.top;
  });
  hero.addEventListener('mouseleave', function () { mouse.x = -9999; mouse.y = -9999; });

  var rt;
  window.addEventListener('resize', function () {
    clearTimeout(rt);
    rt = setTimeout(function () { resize(); if (reduce) frame(false); }, 150);
  });

  resize();
  if (reduce) { frame(false); } else { animate(); }
})();

/* Hexagon markers on the Leaflet maps (ADR-160).
   A circle marker with the option hex: true draws a pointy-top hexagon, as
   the name grid and the help site do. An L.Circle has no such option: its
   radius is a distance on the ground, so it stays a circle. Both maps use
   preferCanvas, so only the canvas renderer needs the patch. */
(function () {
  "use strict";

  // Same area as a circle of radius r.
  var HEX_SCALE = 1.1;

  function patch() {
    if (!window.L || !L.Canvas || L.Canvas.prototype._sairaHex) return;
    var drawCircle = L.Canvas.prototype._updateCircle;
    L.Canvas.prototype._updateCircle = function (layer) {
      if (!layer.options.hex) return drawCircle.call(this, layer);
      if (!this._drawing || layer._empty()) return;
      var p = layer._point;
      var r = Math.max(layer._radius, 1) * HEX_SCALE;
      var ctx = this._ctx;
      ctx.beginPath();
      for (var i = 0; i < 6; i++) {
        var a = Math.PI / 3 * i - Math.PI / 2;
        var x = p.x + r * Math.cos(a);
        var y = p.y + r * Math.sin(a);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.closePath();
      this._fillStroke(ctx, layer);
    };
    L.Canvas.prototype._sairaHex = true;
  }

  patch();
  // A map in a renderUI output loads Leaflet after this file.
  $(patch);
  $(document).on("shiny:value", patch);
})();

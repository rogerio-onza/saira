// Leaflet view bounds (ADR-170 moved it out of utils_coords.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  // The tiles do not wrap, so the minimum zoom is the first one whose world
  // fills the map width (256 px per tile). A resize computes it again.
  behavior.leafletFillWorld = function () {
    return function () {
      var map = this;
      map.options.maxBoundsViscosity = 1;
      function fillWorld() {
        var width = map.getSize().x;
        if (width > 0) map.setMinZoom(Math.max(1, Math.ceil(Math.log2(width / 256))));
      }
      fillWorld();
      map.on('resize', fillWorld);
    };
  };
})();

// Generalization page behavior (ADR-170 moved it out of
// mod_sensitive_coords.R).
(function () {
  "use strict";

  var behavior = (window.sairaModuleBehavior = window.sairaModuleBehavior || {});

  // The exception rows render per species, so one delegated handler serves
  // every row (same pattern as the coordinates undo).
  behavior.sensitiveOverrideRemove = function (cfg) {
    $(document).on('click', '.sp-override-remove', function (e) {
      e.preventDefault();
      Shiny.setInputValue(cfg.removeId, this.dataset.species, { priority: 'event' });
    });
  };

  // The dark stroke of the original points is lost on the satellite layer,
  // so the points switch to a white one there, new points included (ADR-132).
  behavior.sensitiveMapStroke = function () {
    return function () {
      var map = this;
      var stroke = function () {
        return map._sairaSat ? '#ffffff' : '#1C1C26';
      };
      var origin = function () {
        return map.layerManager && map.layerManager.getLayerGroup('orig_points');
      };
      map.on('baselayerchange', function (e) {
        map._sairaSat = e.name === 'Esri.WorldImagery';
        var group = origin();
        if (!group) return;
        group.eachLayer(function (layer) {
          if (layer.setStyle) layer.setStyle({ color: stroke() });
        });
      });
      map.on('layeradd', function (e) {
        var group = origin();
        if (map._sairaSat && group && group.hasLayer(e.layer) && e.layer.setStyle) {
          e.layer.setStyle({ color: stroke() });
        }
      });
    };
  };
})();

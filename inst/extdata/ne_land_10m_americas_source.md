# Embedded Natural Earth 10m Americas Reference

This package ships `ne_land_10m_americas.rds`, an embedded land-mask reference
used by `saira` for `cc_sea(scale = 10)` over the Americas.

Source dataset:
- Natural Earth
- Layer: `land`
- Scale: `10m`
- Category: `physical`
- URL: <https://naciscdn.org/naturalearth/10m/physical/ne_10m_land.zip>

Derivation:
- cropped to an Americas-focused geographic mask in longitude/latitude space,
  including the Caribbean and eastern wraparound used by the Aleutians
- dissolved into a single terrestrial mask
- accompanied by a buffered Americas coverage geometry used to decide when the
  runtime can safely apply the embedded `10m` reference
- saved as a compressed `.rds` artifact for offline runtime loading

License / terms:
- Natural Earth data are public domain
- see <https://www.naturalearthdata.com/about/terms-of-use/>

Generation:
- script: `data-raw/generate_ne_land_10m_americas.R`

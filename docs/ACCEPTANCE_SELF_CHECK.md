# Acceptance self-check

- Repository: `https://github.com/liyun6666/moonbit9` (target default branch `main`).
- MoonBit is the primary implementation language. The current local toolchain is 0.10.9.
- Scope is SHP/SHX/DBF geometry and attribute exchange, filtering and GeoJSON conversion.
- `moon test -p liyun6666/moonbit9` currently passes the full test suite, including malformed binary inputs,
  deletion flags, exact DBF values, topology validation and Z/M round trips.
- Core public functions are `read_shp`, `write_shp`, `read_index`, `validate_shx`, `read_dataset`,
  `write_dataset`, `shape_from_geojson` and `Shape::to_geojson`.
- The repository is published as `liyun6666/moonbit9@0.1.0` on Mooncakes.
- The intended contest history is at least ten meaningful commits; history currently contains ten functional milestones.

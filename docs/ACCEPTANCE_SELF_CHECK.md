# Acceptance self-check

- Repository: `https://github.com/liyun6666/moonbit9` (target default branch `main`).
- MoonBit is the primary implementation language. The current local toolchain is 0.10.9.
- Scope is SHP/SHX/DBF geometry and attribute exchange, filtering and GeoJSON conversion.
- `moon test -p liyun6666/moonbit9` currently passes 31 tests, including malformed binary inputs,
  deletion flags, exact DBF values, topology validation and Z/M round trips.
- Core public functions are `read_shp`, `write_shp`, `read_index`, `validate_shx`, `read_dataset`,
  `write_dataset`, `shape_from_geojson` and `Shape::to_geojson`.
- The repository still needs a user-authenticated push and Mooncakes publication from the owner account.
- The intended contest history is at least ten meaningful commits; history currently contains ten functional milestones.

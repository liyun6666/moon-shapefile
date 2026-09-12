# moonbit9

Shapefile geometry, index and attribute-table IO in MoonBit.

MoonBit-native SHP/SHX/DBF reading and writing with checked offsets, typed
geometry, aligned attribute rows, GeoJSON conversion, filtering and malformed
input diagnostics.

```mbt
let files = @moonbit9.write_shp(@moonbit9.Point, [
  { kind: @moonbit9.Point, points: [@moonbit9.coordinate(116.4, 39.9)], parts: [] },
])
let parsed = @moonbit9.read_shp(files.shp)
```

Run `moon test` for the binary, geometry and interoperability regression suite.
The accepted scope and explicit non-goals are in [docs/design.md](docs/design.md).

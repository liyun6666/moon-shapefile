///|
fn main raise {
  let dataset : @shapefile.Dataset = {
    kind: @shapefile.Point,
    shapes: [
      {
        kind: @shapefile.Point,
        points: [@shapefile.coordinate(116.4, 39.9)],
        parts: [],
      },
    ],
    table: {
      fields: [{ name: "NAME", kind: @dbf.Character, width: 16, decimals: 0 }],
      rows: [{ deleted: false, values: [@dbf.Text("Beijing")] }],
    },
    prj: None,
  }
  let files = dataset.write_dataset()
  let restored = @shapefile.read_dataset(files.shp, files.shx, files.dbf)
  assert_eq(restored.shapes, dataset.shapes)
  assert_eq(restored.table, dataset.table)
  let selected = restored.filter_equal("NAME", @dbf.Text("Beijing"))
  assert_eq(selected.shapes.length(), 1)
  let json = selected.to_geojson()
  assert_eq(json, {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "geometry": { "type": "Point", "coordinates": [116.4, 39.9] },
        "properties": { "NAME": "Beijing" },
      },
    ],
  })
  println(json.stringify())
}

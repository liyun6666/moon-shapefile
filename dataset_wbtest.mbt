///|
fn review_dataset(table : @dbf.Table) -> Dataset {
  {
    kind: Point,
    shapes: table.rows.map(_ => {
      kind: Point,
      points: [coordinate(1.0, 2.0)],
      parts: [],
    }),
    table,
    prj: Some("opaque projection metadata"),
  }
}

///|
test "Latin1 dataset preserves one-byte accented values across read write and export" {
  let table : @dbf.Table = {
    fields: [{ name: "NAME", kind: @dbf.Character, width: 1, decimals: 0 }],
    rows: [{ deleted: false, values: [@dbf.Text("é")] }],
  }
  let original = review_dataset(table)
  let files = original.write_dataset(encoding=@dbf.Latin1)
  let restored = read_dataset(
    files.shp,
    files.shx,
    files.dbf,
    encoding=@dbf.Latin1,
    prj=files.prj,
  )
  assert_eq(restored.table, table)
  assert_eq(restored.shapes, original.shapes)
  assert_eq(restored.prj, original.prj)
  restored.validate(encoding=@dbf.Latin1)
  assert_eq(restored.to_geojson(encoding=@dbf.Latin1), {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "geometry": { "type": "Point", "coordinates": [1, 2] },
        "properties": { "NAME": "é" },
      },
    ],
  })
  assert_true(
    try {
      ignore(original.write_dataset())
      false
    } catch {
      _ => true
    },
  )
}

///|
test "GeoJSON properties retain exact decimals dates booleans missing and row alignment" {
  let fields : Array[@dbf.Field] = [
    { name: "NAME", kind: @dbf.Character, width: 12, decimals: 0 },
    { name: "NUMBER", kind: @dbf.Numeric, width: 24, decimals: 2 },
    { name: "FLOAT", kind: @dbf.Float, width: 8, decimals: 2 },
    { name: "DATE", kind: @dbf.Date, width: 8, decimals: 0 },
    { name: "FLAG", kind: @dbf.Logical, width: 1, decimals: 0 },
    { name: "EMPTY", kind: @dbf.Numeric, width: 4, decimals: 0 },
  ]
  let values = [
    @dbf.Text("中文"),
    @dbf.Number("9007199254740993.00"),
    @dbf.Number("+01.20"),
    @dbf.DateValue("20260923"),
    @dbf.LogicalValue(false),
    @dbf.Missing,
  ]
  let dataset = review_dataset({
    fields,
    rows: [{ deleted: true, values }, { deleted: false, values }],
  })
  let feature : Json = {
    "type": "Feature",
    "geometry": { "type": "Point", "coordinates": [1, 2] },
    "properties": {
      "NAME": "中文",
      "NUMBER": "9007199254740993.00",
      "FLOAT": "+01.20",
      "DATE": "20260923",
      "FLAG": false,
      "EMPTY": null,
    },
  }
  assert_eq(dataset.to_geojson(), {
    "type": "FeatureCollection",
    "features": [feature],
  })
  assert_eq(dataset.to_geojson(include_deleted=true), {
    "type": "FeatureCollection",
    "features": [feature, feature],
  })
  let selected = dataset.select_indices([1, 0])
  assert_eq(selected.table.rows[0].deleted, false)
  assert_eq(selected.table.rows[1].deleted, true)
}

///|
test "dataset export rejects malformed rows and unrepresentable Latin1" {
  let dataset = review_dataset({
    fields: [{ name: "NAME", kind: @dbf.Character, width: 12, decimals: 0 }],
    rows: [{ deleted: false, values: [@dbf.Text("中文")] }],
  })
  assert_true(
    try {
      ignore(dataset.write_dataset(encoding=@dbf.Latin1))
      false
    } catch {
      _ => true
    },
  )
  dataset.table.rows[0].values.clear()
  assert_true(
    try {
      ignore(dataset.to_geojson())
      false
    } catch {
      _ => true
    },
  )
}

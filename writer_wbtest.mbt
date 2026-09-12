///|
test "point encoder matches independent byte fixture" {
  let shape : Shape = { kind: Point, points: [coordinate(1.0, 2.0)], parts: [] }
  let output = write_shp(Point, [shape])
  assert_eq(output.shp, point_fixture())
  assert_eq(output.shx, point_index_fixture())
}

///|
test "writer rejects type mismatch before producing files" {
  let shape : Shape = { kind: Point, points: [coordinate(1.0, 2.0)], parts: [] }
  assert_true(
    try {
      ignore(write_shp(Polygon, [shape]))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "null entries preserve their ordinal and Z point missing M" {
  let shape : Shape = {
    kind: PointZ,
    points: [coordinate(1.0, 2.0, z=3.0)],
    parts: [],
  }
  let empty : Shape = { kind: Null, points: [], parts: [] }
  let files = write_shp(PointZ, [empty, shape])
  validate_shx(files.shp, files.shx)
  let records = read_shp(files.shp).records
  assert_eq(records.length(), 2)
  assert_eq(records[1].shape.points[0].z, Some(3.0))
  assert_eq(records[1].shape.points[0].m, None)
}

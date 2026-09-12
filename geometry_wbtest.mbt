test "geometry type and bounds contract" {
  let s : Shape = { kind: PointZ, points: [coordinate(3.0, 4.0, z=2.0)], parts: [] }
  s.validate()
  assert_eq(s.kind.code(), 11)
  assert_true(s.kind.has_z())
  assert_eq(s.bounds(), Some({ xmin: 3.0, ymin: 4.0, xmax: 3.0, ymax: 4.0 }))
}

test "reject incomplete polygon" {
  let s : Shape = { kind: Polygon, points: [coordinate(0.0,0.0),coordinate(1.0,0.0)], parts: [0] }
  let rejected = try { s.validate(); false } catch { _ => true }
  assert_true(rejected)
}

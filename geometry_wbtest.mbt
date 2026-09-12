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
test "spatial intersection distinguishes bounding rectangle from line" {
  let line : Shape = { kind: PolyLine, points: [coordinate(0.0,0.0),coordinate(10.0,10.0)], parts: [0] }
  let box : Bounds = { xmin: 0.0, ymin: 8.0, xmax: 2.0, ymax: 10.0 }
  assert_true(!line.intersects_bounds(box))
  assert_true(line.contains_point(coordinate(5.0,5.0)))
  assert_true(!line.contains_point(coordinate(5.0,6.0)))
}

test "planar area and holes use nesting independent of winding" {
  let points = test_ring(0.0,10.0)
  points.append(test_ring(2.0,8.0))
  let polygon : Shape = { kind: Polygon, points, parts: [0,5] }
  assert_eq(polygon.planar_area(),64.0)
  assert_eq(polygon.planar_length(),64.0)
  assert_true(polygon.contains_point(coordinate(1.0,1.0)))
  assert_true(!polygon.contains_point(coordinate(5.0,5.0)))
  assert_true(polygon.contains_point(coordinate(2.0,5.0)))
  assert_true(!polygon.intersects_bounds({ xmin: 3.0,ymin: 3.0,xmax: 4.0,ymax: 4.0 }))
  assert_true(polygon.intersects_bounds({ xmin: 0.5,ymin: 0.5,xmax: 1.0,ymax: 1.0 }))
}
test "all supported type codes round trip and unknown codes reject" {
  let codes = [0,1,3,5,8,11,13,15,18,21,23,25,28]
  for code in codes { assert_eq(shape_type(code).code(),code) }
  for code in [-1,2,4,6,31,999] {
    assert_true(try { ignore(shape_type(code)); false } catch { _ => true })
  }
}

test "geometry validation rejects malformed dimensions parts and coordinates" {
  let cases : Array[Shape] = [
    { kind: Null, points: [coordinate(0.0,0.0)], parts: [] },
    { kind: Point, points: [], parts: [] },
    { kind: PointZ, points: [coordinate(0.0,0.0)], parts: [] },
    { kind: Point, points: [coordinate(0.0,0.0,z=1.0)], parts: [] },
    { kind: Point, points: [coordinate(0.0,0.0,m=1.0)], parts: [] },
    { kind: Point, points: [coordinate(0.0,0.0)], parts: [0] },
    { kind: MultiPoint, points: [coordinate(0.0,0.0)], parts: [0] },
    { kind: PolyLine, points: [coordinate(0.0,0.0),coordinate(1.0,1.0)], parts: [1] },
    { kind: PolyLine, points: [coordinate(0.0,0.0),coordinate(1.0,1.0)], parts: [0,0] },
    { kind: PolyLine, points: [coordinate(0.0,0.0),coordinate(1.0,1.0)], parts: [0,3] },
    { kind: Point, points: [coordinate(1.0 / 0.0,0.0)], parts: [] },
    { kind: PointZ, points: [coordinate(0.0,0.0,z=0.0 / 0.0)], parts: [] },
    { kind: PointM, points: [coordinate(0.0,0.0,m=1.0 / 0.0)], parts: [] },
  ]
  for shape in cases {
    assert_true(try { shape.validate(); false } catch { _ => true })
  }
}

test "bounds union intersection and invalid ranges" {
  let a : Bounds = { xmin: 0.0,ymin: 0.0,xmax: 4.0,ymax: 4.0 }
  let b : Bounds = { xmin: 4.0,ymin: 2.0,xmax: 8.0,ymax: 8.0 }
  assert_eq(a.intersection(b),Some({ xmin: 4.0,ymin: 2.0,xmax: 4.0,ymax: 4.0 }))
  assert_eq(a.union(b),{ xmin: 0.0,ymin: 0.0,xmax: 8.0,ymax: 8.0 })
  assert_true(a.contains(coordinate(4.0,4.0)))
  let invalid : Bounds = { xmin: 4.0,ymin: 0.0,xmax: 0.0,ymax: 4.0 }
  assert_true(try { invalid.validate(); false } catch { _ => true })
}

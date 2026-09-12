///|
test "GeoJSON point preserves Z and omits measure" {
  let shape : Shape = {
    kind: PointZ,
    points: [coordinate(1.0, 2.0, z=3.0, m=4.0)],
    parts: [],
  }
  assert_eq(shape.to_geojson(), { "type": "Point", "coordinates": [1, 2, 3] })
}

///|
test "GeoJSON rejects projected point by default" {
  let shape : Shape = {
    kind: Point,
    points: [coordinate(1000.0, 2000.0)],
    parts: [],
  }
  assert_true(
    try {
      ignore(shape.to_geojson())
      false
    } catch {
      _ => true
    },
  )
  assert_eq(shape.to_geojson(allow_projected=true), {
    "type": "Point",
    "coordinates": [1000, 2000],
  })
}

///|
fn test_ring(low : Double, high : Double) -> Array[Coordinate] {
  [
    coordinate(low, low),
    coordinate(high, low),
    coordinate(high, high),
    coordinate(low, high),
    coordinate(low, low),
  ]
}

///|
test "rings in arbitrary order become shell hole and island" {
  let points = test_ring(2.0, 8.0)
  points.append(test_ring(0.0, 10.0))
  points.append(test_ring(3.0, 4.0))
  let shape : Shape = { kind: Polygon, points, parts: [0, 5, 10] }
  let expected : Json = {
    "type": "MultiPolygon",
    "coordinates": [
      [
        [[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]],
        [[2, 2], [2, 8], [8, 8], [8, 2], [2, 2]],
      ],
      [[[3, 3], [4, 3], [4, 4], [3, 4], [3, 3]]],
    ],
  }
  assert_eq(shape.to_geojson(), expected)
}

///|
test "crossing self-intersection touching and backtracking rejected" {
  let bad : Array[Array[Coordinate]] = [
    [
      coordinate(0.0, 0.0),
      coordinate(4.0, 4.0),
      coordinate(0.0, 4.0),
      coordinate(4.0, 0.0),
      coordinate(0.0, 0.0),
    ],
    [
      coordinate(0.0, 0.0),
      coordinate(4.0, 0.0),
      coordinate(2.0, 0.0),
      coordinate(0.0, 4.0),
      coordinate(0.0, 0.0),
    ],
    [
      coordinate(0.0, 0.0),
      coordinate(4.0, 0.0),
      coordinate(2.0, 2.0),
      coordinate(4.0, 4.0),
      coordinate(0.0, 4.0),
      coordinate(2.0, 2.0),
      coordinate(0.0, 0.0),
    ],
  ]
  for points in bad {
    let shape : Shape = { kind: Polygon, points, parts: [0] }
    assert_true(
      try {
        ignore(shape.to_geojson())
        false
      } catch {
        _ => true
      },
    )
  }
  let points = test_ring(0.0, 4.0)
  points.append(test_ring(3.0, 6.0))
  let shape : Shape = { kind: Polygon, points, parts: [0, 5] }
  assert_true(
    try {
      ignore(shape.to_geojson())
      false
    } catch {
      _ => true
    },
  )
}

///|
test "collinear forward edges allowed and clockwise shell reversed" {
  let shape : Shape = {
    kind: Polygon,
    points: [
      coordinate(0.0, 0.0),
      coordinate(0.0, 4.0),
      coordinate(4.0, 4.0),
      coordinate(4.0, 0.0),
      coordinate(2.0, 0.0),
      coordinate(0.0, 0.0),
    ],
    parts: [0],
  }
  assert_eq(shape.to_geojson(), {
    "type": "Polygon",
    "coordinates": [[[0, 0], [2, 0], [4, 0], [4, 4], [0, 4], [0, 0]]],
  })
}

///|
test "null and multiple lines serialize" {
  let empty : Shape = { kind: Null, points: [], parts: [] }
  assert_eq(empty.to_geojson(), Json::null())
  let lines : Shape = {
    kind: PolyLine,
    points: [
      coordinate(0.0, 0.0),
      coordinate(1.0, 1.0),
      coordinate(2.0, 2.0),
      coordinate(3.0, 3.0),
    ],
    parts: [0, 2],
  }
  assert_eq(lines.to_geojson(), {
    "type": "MultiLineString",
    "coordinates": [[[0, 0], [1, 1]], [[2, 2], [3, 3]]],
  })
}

///|
test "GeoJSON import preserves target type and normalizes shell" {
  let input : Json = {
    "type": "Polygon",
    "coordinates": [[[0, 0], [4, 0], [4, 4], [0, 4], [0, 0]]],
  }
  let result = shape_from_geojson(input, Polygon)
  assert_eq(result.parts, [0])
  assert_true(result.ring_area(0) < 0.0)
  assert_eq(result.to_geojson(), input)
}

///|
test "GeoJSON import refuses dimension loss and unsupported families" {
  let point : Json = { "type": "Point", "coordinates": [1, 2, 3] }
  assert_true(
    try {
      ignore(shape_from_geojson(point, Point))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(shape_from_geojson(point, PointZ).points[0].z, Some(3.0))
  assert_true(
    try {
      ignore(shape_from_geojson(point, Polygon))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "GeoJSON import rejects malformed structures" {
  let cases : Array[Json] = [
    4,
    {},
    { "type": "Point" },
    { "type": "Point", "coordinates": [1] },
    { "type": "Point", "coordinates": [1, "bad"] },
    { "type": "GeometryCollection", "coordinates": [] },
  ]
  for value in cases {
    assert_true(
      try {
        ignore(shape_from_geojson(value, Point))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "GeoJSON holes must belong to specified shell" {
  let outside : Json = {
    "type": "Polygon",
    "coordinates": [
      [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]],
      [[4, 4], [5, 4], [5, 5], [4, 5], [4, 4]],
    ],
  }
  assert_true(
    try {
      ignore(shape_from_geojson(outside, Polygon))
      false
    } catch {
      _ => true
    },
  )
  let overlap : Json = {
    "type": "MultiPolygon",
    "coordinates": [
      [[[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]]],
      [[[2, 2], [4, 2], [4, 4], [2, 4], [2, 2]]],
    ],
  }
  assert_true(
    try {
      ignore(shape_from_geojson(overlap, Polygon))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "GeoJSON measures remain absent and null ignores target kind" {
  let point : Json = { "type": "Point", "coordinates": [1, 2] }
  let shape = shape_from_geojson(point, PointM)
  assert_eq(shape.points[0].m, None)
  assert_eq(shape.to_geojson(), point)
  assert_eq(shape_from_geojson(Json::null(), Polygon).kind, Null)
}

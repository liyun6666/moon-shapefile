///|
/// Small, allocation-conscious geometry operations used by importers.
pub fn translate_shape(
  shape : Shape,
  dx : Double,
  dy : Double,
) -> Shape raise ShapeError {
  shape.validate()
  if !finite(dx) || !finite(dy) {
    raise InvalidData(0, "nonfinite translation")
  }
  let points = shape.points.map(p => {
    x: p.x + dx,
    y: p.y + dy,
    z: p.z,
    m: p.m,
  })
  { kind: shape.kind, points, parts: shape.parts.copy() }
}

///|
pub fn scale_shape(
  shape : Shape,
  sx : Double,
  sy : Double,
) -> Shape raise ShapeError {
  shape.validate()
  if !finite(sx) || !finite(sy) || sx == 0.0 || sy == 0.0 {
    raise InvalidData(0, "invalid scale")
  }
  let points = shape.points.map(p => {
    x: p.x * sx,
    y: p.y * sy,
    z: p.z,
    m: p.m,
  })
  let result : Shape = { kind: shape.kind, points, parts: shape.parts.copy() }
  result.validate()
  result
}

///|
pub fn reverse_parts(shape : Shape) -> Shape raise ShapeError {
  shape.validate()
  let points : Array[Coordinate] = []
  let parts : Array[Int] = []
  for part = 0; part < shape.parts.length(); part = part + 1 {
    parts.push(points.length())
    let start = shape.parts[part]
    let end = shape.part_end(part)
    let mut i = end - 1
    while i >= start {
      points.push(shape.points[i])
      i = i - 1
    }
  }
  { kind: shape.kind, points, parts }
}

///|
pub fn centroid(shape : Shape) -> Coordinate? raise ShapeError {
  shape.validate()
  if shape.points.is_empty() {
    return None
  }
  let mut x = 0.0
  let mut y = 0.0
  for p in shape.points {
    x += p.x
    y += p.y
  }
  Some(
    coordinate(
      x / shape.points.length().to_double(),
      y / shape.points.length().to_double(),
    ),
  )
}

///|
pub fn nearest_vertex(
  shape : Shape,
  target : Coordinate,
) -> (Int, Double)? raise ShapeError {
  shape.validate()
  let mut best : (Int, Double)? = None
  for i = 0; i < shape.points.length(); i = i + 1 {
    let p = shape.points[i]
    let dx = p.x - target.x
    let dy = p.y - target.y
    let d = dx * dx + dy * dy
    match best {
      None => best = Some((i, d))
      Some((_, old)) => if d < old { best = Some((i, d)) }
    }
  }
  best
}

///|
pub fn clamp_bounds(shape : Shape, bounds : Bounds) -> Shape raise ShapeError {
  shape.validate()
  bounds.validate()
  let points = shape.points.map(p => {
    x: if p.x < bounds.xmin {
      bounds.xmin
    } else if p.x > bounds.xmax {
      bounds.xmax
    } else {
      p.x
    },
    y: if p.y < bounds.ymin {
      bounds.ymin
    } else if p.y > bounds.ymax {
      bounds.ymax
    } else {
      p.y
    },
    z: p.z,
    m: p.m,
  })
  let result : Shape = { kind: shape.kind, points, parts: shape.parts.copy() }
  result.validate()
  result
}

///|
test "transformations preserve metadata and centroid" {
  let shape : Shape = { kind: Point, points: [coordinate(1.0, 2.0)], parts: [] }
  assert_eq(translate_shape(shape, 2.0, 3.0).points[0], coordinate(3.0, 5.0))
  assert_eq(scale_shape(shape, 2.0, 2.0).points[0], coordinate(2.0, 4.0))
  assert_eq(centroid(shape), Some(coordinate(1.0, 2.0)))
  assert_eq(nearest_vertex(shape, coordinate(1.2, 2.1)).unwrap().0, 0)
}

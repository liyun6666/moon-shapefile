///|
/// Summary statistics useful to import pipelines and CLI reports.
pub(all) struct ShapeStats {
  record_count : Int
  point_count : Int
  part_count : Int
  null_count : Int
  bounds : Bounds?
  total_length : Double
  total_area : Double
} derive(Debug)

///|
pub fn summarize(shapes : Array[Shape]) -> ShapeStats raise ShapeError {
  let mut points = 0
  let mut parts = 0
  let mut nulls = 0
  let mut length = 0.0
  let mut area = 0.0
  let mut bounds : Bounds? = None
  for shape in shapes {
    shape.validate()
    points += shape.points.length()
    parts += shape.parts.length()
    if shape.kind == Null {
      nulls += 1
    }
    length += shape.planar_length()
    area += shape.planar_area()
    bounds = merge_bounds(bounds, shape.bounds())
  }
  {
    record_count: shapes.length(),
    point_count: points,
    part_count: parts,
    null_count: nulls,
    bounds,
    total_length: length,
    total_area: area,
  }
}

///|
/// Returns physical record indices whose bounding boxes overlap the query.
pub fn intersecting_indices(
  shapes : Array[Shape],
  query : Bounds,
) -> Array[Int] raise ShapeError {
  query.validate()
  let result : Array[Int] = []
  for i in 0..<shapes.length() {
    if shapes[i].intersects_bounds(query) {
      result.push(i)
    }
  }
  result
}

///|
/// Stable filter preserving original record order and duplicate indices.
pub fn stable_select(
  shapes : Array[Shape],
  indices : Array[Int],
) -> Array[Shape] raise ShapeError {
  let result : Array[Shape] = []
  for i in indices {
    if i < 0 || i >= shapes.length() {
      raise InvalidData(i, "shape index outside array")
    }
    result.push(shapes[i])
  }
  result
}

///|
/// Validate that a collection has one file-compatible shape family.
pub fn validate_shape_family(
  kind : ShapeType,
  shapes : Array[Shape],
) -> Unit raise ShapeError {
  let mut seen_z = false
  let mut seen_m = false
  for shape in shapes {
    if shape.kind != Null && shape.kind != kind {
      raise InvalidData(0, "mixed shape families")
    }
    shape.validate()
    seen_z = seen_z || shape.kind.has_z()
    seen_m = seen_m || shape.kind.has_m()
  }
  if seen_z != kind.has_z() || seen_m != kind.has_m() {
    raise InvalidData(0, "shape family dimensions disagree")
  }
}

///|
pub fn bounds_of(shapes : Array[Shape]) -> Bounds? raise ShapeError {
  let mut result : Bounds? = None
  for shape in shapes {
    shape.validate()
    result = merge_bounds(result, shape.bounds())
  }
  result
}

///|
pub fn count_vertices(shapes : Array[Shape]) -> Int raise ShapeError {
  let mut n = 0
  for shape in shapes {
    shape.validate()
    n += shape.points.length()
  }
  n
}

///|
pub fn count_parts(shapes : Array[Shape]) -> Int raise ShapeError {
  let mut n = 0
  for shape in shapes {
    shape.validate()
    n += shape.parts.length()
  }
  n
}

///|
/// Return the first record that contains a point under inclusive XY semantics.
pub fn locate_point(
  shapes : Array[Shape],
  point : Coordinate,
) -> Int? raise ShapeError {
  for i in 0..<shapes.length() {
    if shapes[i].contains_point(point) {
      return Some(i)
    }
  }
  None
}

///|
/// Compute a histogram of records by ShapeType numeric code.
pub fn type_histogram(shapes : Array[Shape]) -> Map[Int, Int] raise ShapeError {
  let result : Map[Int, Int] = Map([])
  for shape in shapes {
    shape.validate()
    let code = shape.kind.code()
    result[code] = result.get(code).unwrap_or(0) + 1
  }
  result
}

///|
/// Check that all bounds are finite and mutually compatible with their shapes.
pub fn validate_bounds(
  shapes : Array[Shape],
  declared : Bounds,
) -> Unit raise ShapeError {
  declared.validate()
  for shape in shapes {
    shape.validate()
    match shape.bounds() {
      Some(b) =>
        if b.xmin < declared.xmin ||
          b.ymin < declared.ymin ||
          b.xmax > declared.xmax ||
          b.ymax > declared.ymax {
          raise InvalidData(0, "shape lies outside declared bounds")
        }
      None => ()
    }
  }
}

///|
/// Calculate the fraction of points that carry a Z ordinate.
pub fn z_coverage(shapes : Array[Shape]) -> Double raise ShapeError {
  let mut total = 0
  let mut with_z = 0
  for shape in shapes {
    shape.validate()
    for p in shape.points {
      total += 1
      if p.z is Some(_) {
        with_z += 1
      }
    }
  }
  if total == 0 {
    0.0
  } else {
    with_z.to_double() / total.to_double()
  }
}

///|
/// Calculate the fraction of points that carry an M ordinate.
pub fn m_coverage(shapes : Array[Shape]) -> Double raise ShapeError {
  let mut total = 0
  let mut with_m = 0
  for shape in shapes {
    shape.validate()
    for p in shape.points {
      total += 1
      if p.m is Some(_) {
        with_m += 1
      }
    }
  }
  if total == 0 {
    0.0
  } else {
    with_m.to_double() / total.to_double()
  }
}

///|
test "summarize and spatial selection preserve physical order" {
  let shapes = [
    { kind: Point, points: [coordinate(1.0, 2.0)], parts: [] },
    { kind: Point, points: [coordinate(9.0, 9.0)], parts: [] },
  ]
  let stats = summarize(shapes)
  assert_eq(stats.record_count, 2)
  assert_eq(stats.point_count, 2)
  assert_eq(
    intersecting_indices(shapes, { xmin: 0.0, ymin: 0.0, xmax: 2.0, ymax: 3.0 }),
    [0],
  )
  assert_eq(stable_select(shapes, [1, 0, 1]).length(), 3)
}

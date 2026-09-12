///|
/// ESRI shape codes. MultiPatch is deliberately unsupported.
pub(all) enum ShapeType {
  Null
  Point
  PolyLine
  Polygon
  MultiPoint
  PointZ
  PolyLineZ
  PolygonZ
  MultiPointZ
  PointM
  PolyLineM
  PolygonM
  MultiPointM
} derive(Debug, Eq)

///|
pub(all) struct Coordinate {
  x : Double
  y : Double
  z : Double?
  m : Double?
} derive(Debug, Eq)

///|
pub(all) struct Shape {
  kind : ShapeType
  points : Array[Coordinate]
  parts : Array[Int]
} derive(Debug, Eq)

///|
pub(all) struct Bounds {
  xmin : Double
  ymin : Double
  xmax : Double
  ymax : Double
} derive(Debug, Eq)

///|
pub fn coordinate(
  x : Double,
  y : Double,
  z? : Double,
  m? : Double,
) -> Coordinate {
  { x, y, z, m }
}

///|
pub fn ShapeType::code(self : ShapeType) -> Int {
  match self {
    Null => 0
    Point => 1
    PolyLine => 3
    Polygon => 5
    MultiPoint => 8
    PointZ => 11
    PolyLineZ => 13
    PolygonZ => 15
    MultiPointZ => 18
    PointM => 21
    PolyLineM => 23
    PolygonM => 25
    MultiPointM => 28
  }
}

///|
pub fn shape_type(code : Int) -> ShapeType raise ShapeError {
  match code {
    0 => Null
    1 => Point
    3 => PolyLine
    5 => Polygon
    8 => MultiPoint
    11 => PointZ
    13 => PolyLineZ
    15 => PolygonZ
    18 => MultiPointZ
    21 => PointM
    23 => PolyLineM
    25 => PolygonM
    28 => MultiPointM
    _ => raise InvalidData(0, "unsupported shape type")
  }
}

///|
pub fn ShapeType::has_z(self : ShapeType) -> Bool {
  self is PointZ || self is PolyLineZ || self is PolygonZ || self is MultiPointZ
}

///|
pub fn ShapeType::has_m(self : ShapeType) -> Bool {
  self.has_z() ||
  self is PointM ||
  self is PolyLineM ||
  self is PolygonM ||
  self is MultiPointM
}

///|
pub fn ShapeType::is_point(self : ShapeType) -> Bool {
  self is Point || self is PointZ || self is PointM
}

///|
pub fn ShapeType::is_multi(self : ShapeType) -> Bool {
  self is MultiPoint || self is MultiPointZ || self is MultiPointM
}

///|
pub fn ShapeType::is_polygon(self : ShapeType) -> Bool {
  self is Polygon || self is PolygonZ || self is PolygonM
}

///|
pub fn ShapeType::is_line(self : ShapeType) -> Bool {
  self is PolyLine || self is PolyLineZ || self is PolyLineM
}

///|
pub fn Bounds::validate(self : Bounds) -> Unit raise ShapeError {
  if !finite(self.xmin) ||
    !finite(self.ymin) ||
    !finite(self.xmax) ||
    !finite(self.ymax) {
    raise InvalidData(0, "nonfinite bounds")
  }
  if self.xmin > self.xmax || self.ymin > self.ymax {
    raise InvalidData(0, "reversed bounds")
  }
}

///|
pub fn Bounds::contains(self : Bounds, point : Coordinate) -> Bool {
  point.x >= self.xmin &&
  point.x <= self.xmax &&
  point.y >= self.ymin &&
  point.y <= self.ymax
}

///|
pub fn Bounds::intersects(self : Bounds, other : Bounds) -> Bool {
  self.xmin <= other.xmax &&
  self.xmax >= other.xmin &&
  self.ymin <= other.ymax &&
  self.ymax >= other.ymin
}

///|
pub fn Shape::bounds(self : Shape) -> Bounds? {
  if self.points.is_empty() {
    return None
  }
  let p = self.points[0]
  let mut xmin = p.x
  let mut xmax = p.x
  let mut ymin = p.y
  let mut ymax = p.y
  for p in self.points {
    if p.x < xmin {
      xmin = p.x
    }
    if p.x > xmax {
      xmax = p.x
    }
    if p.y < ymin {
      ymin = p.y
    }
    if p.y > ymax {
      ymax = p.y
    }
  }
  Some({ xmin, ymin, xmax, ymax })
}

///|
fn same_xy(a : Coordinate, b : Coordinate) -> Bool {
  a.x == b.x && a.y == b.y
}

///|
fn Shape::part_end(self : Shape, part : Int) -> Int {
  if part + 1 < self.parts.length() {
    self.parts[part + 1]
  } else {
    self.points.length()
  }
}

///|
pub fn Shape::validate(self : Shape) -> Unit raise ShapeError {
  if self.kind == Null {
    if !self.points.is_empty() || !self.parts.is_empty() {
      raise InvalidData(0, "null shape must be empty")
    }
    return
  }
  if self.points.is_empty() {
    raise InvalidData(0, "non-null shape has no points")
  }
  for i = 0; i < self.points.length(); i = i + 1 {
    let p = self.points[i]
    if !finite(p.x) || !finite(p.y) {
      raise InvalidData(i, "nonfinite XY coordinate")
    }
    match p.z {
      Some(z) => {
        if !finite(z) {
          raise InvalidData(i, "nonfinite Z coordinate")
        }
        if !self.kind.has_z() {
          raise InvalidData(i, "Z coordinate on non-Z shape")
        }
      }
      None =>
        if self.kind.has_z() {
          raise InvalidData(i, "missing Z coordinate")
        }
    }
    match p.m {
      Some(m) => {
        if !finite(m) {
          raise InvalidData(i, "nonfinite measure")
        }
        if m < -1.0e38 {
          raise InvalidData(i, "measure uses reserved no-data range")
        }
        if !self.kind.has_m() {
          raise InvalidData(i, "measure on XY shape")
        }
      }
      None => ()
    }
  }
  if self.kind.is_point() {
    if self.points.length() != 1 || !self.parts.is_empty() {
      raise InvalidData(0, "point shape requires one point and no parts")
    }
    return
  }
  if self.kind.is_multi() {
    if !self.parts.is_empty() {
      raise InvalidData(0, "multipoint cannot contain parts")
    }
    return
  }
  if self.parts.is_empty() || self.parts[0] != 0 {
    raise InvalidData(0, "multipart shape must start with part zero")
  }
  for i = 0; i < self.parts.length(); i = i + 1 {
    let start = self.parts[i]
    let end = self.part_end(i)
    if start < 0 || end > self.points.length() || end <= start {
      raise InvalidData(i, "invalid part index")
    }
    let minimum = if self.kind.is_polygon() { 4 } else { 2 }
    if end - start < minimum {
      raise InvalidData(i, "part has too few points")
    }
    if self.kind.is_polygon() &&
      !same_xy(self.points[start], self.points[end - 1]) {
      raise InvalidData(i, "polygon ring is not closed")
    }
    // Repeated vertices are legal in ESRI records. A part is invalid only
    // when every segment collapses to zero length (handled by topology checks).
  }
}

///|
/// Euclidean length in input XY units. Polygon results include hole boundaries;
/// point geometries have zero length. No geodesic interpretation is implied.
pub fn Shape::planar_length(self : Shape) -> Double raise ShapeError {
  self.validate()
  let mut total = 0.0
  for part = 0; part < self.parts.length(); part = part + 1 {
    for i = self.parts[part]; i + 1 < self.part_end(part); i = i + 1 {
      let dx = self.points[i + 1].x - self.points[i].x
      let dy = self.points[i + 1].y - self.points[i].y
      let ax = if dx < 0.0 { -dx } else { dx }
      let ay = if dy < 0.0 { -dy } else { dy }
      let scale = if ax > ay { ax } else { ay }
      if !finite(scale) {
        raise InvalidData(i, "segment length overflows")
      }
      if scale != 0.0 {
        let sx = dx / scale
        let sy = dy / scale
        total += scale * (sx * sx + sy * sy).sqrt()
      }
      if !finite(total) {
        raise InvalidData(i, "total length overflows")
      }
    }
  }
  total
}

///|
/// Area in squared input XY units after topology validation. Winding has no
/// effect; holes subtract and islands add. Non-polygons return zero.
pub fn Shape::planar_area(self : Shape) -> Double raise ShapeError {
  self.validate()
  if !self.kind.is_polygon() {
    return 0.0
  }
  let parents = self.polygon_parents()
  let mut area = 0.0
  for i = 0; i < parents.length(); i = i + 1 {
    let signed = self.ring_area(i)
    let magnitude = (if signed < 0.0 { -signed } else { signed }) / 2.0
    let mut parent = parents[i]
    let mut depth = 0
    while parent != -1 {
      depth += 1
      if depth > parents.length() {
        raise InvalidData(i, "cyclic polygon nesting")
      }
      parent = parents[parent]
    }
    area += if depth % 2 == 0 { magnitude } else { -magnitude }
    if !finite(area) {
      raise InvalidData(i, "total polygon area overflows")
    }
  }
  area
}

///|
fn Shape::contains_point_unchecked(
  self : Shape,
  point : Coordinate,
) -> Bool raise ShapeError {
  if self.kind.is_point() || self.kind.is_multi() {
    for p in self.points {
      if same_xy(p, point) {
        return true
      }
    }
    return false
  }
  for part = 0; part < self.parts.length(); part = part + 1 {
    for i = self.parts[part]; i + 1 < self.part_end(part); i = i + 1 {
      if on_segment(point, self.points[i], self.points[i + 1]) {
        return true
      }
    }
  }
  if !self.kind.is_polygon() {
    return false
  }
  let mut inside = false
  for part = 0; part < self.parts.length(); part = part + 1 {
    if self.ring_contains(part, point) {
      inside = !inside
    }
  }
  inside
}

///|
/// Inclusive planar membership. Polygon boundaries (including hole boundaries)
/// count as contained. Z and M are ignored; exact XY comparisons are used.
pub fn Shape::contains_point(
  self : Shape,
  point : Coordinate,
) -> Bool raise ShapeError {
  self.validate()
  if !finite(point.x) || !finite(point.y) {
    raise InvalidData(0, "nonfinite query point")
  }
  if self.kind.is_polygon() {
    ignore(self.polygon_parents())
  }
  self.contains_point_unchecked(point)
}

///|
/// True geometric intersection with a closed XY rectangle, including touches.
/// Unlike a bounding-box prefilter, this respects concavities and polygon holes.
pub fn Shape::intersects_bounds(
  self : Shape,
  bounds : Bounds,
) -> Bool raise ShapeError {
  self.validate()
  bounds.validate()
  if self.kind.is_polygon() {
    ignore(self.polygon_parents())
  }
  match self.bounds() {
    None => return false
    Some(own) => if !own.intersects(bounds) { return false }
  }
  for point in self.points {
    if bounds.contains(point) {
      return true
    }
  }
  if self.kind.is_point() || self.kind.is_multi() {
    return false
  }
  let corners = [
    coordinate(bounds.xmin, bounds.ymin),
    coordinate(bounds.xmax, bounds.ymin),
    coordinate(bounds.xmax, bounds.ymax),
    coordinate(bounds.xmin, bounds.ymax),
  ]
  for part = 0; part < self.parts.length(); part = part + 1 {
    for i = self.parts[part]; i + 1 < self.part_end(part); i = i + 1 {
      for side = 0; side < 4; side = side + 1 {
        if segments_intersect(
            self.points[i],
            self.points[i + 1],
            corners[side],
            corners[(side + 1) % 4],
          ) {
          return true
        }
      }
    }
  }
  self.kind.is_polygon() && self.contains_point_unchecked(corners[0])
}

///|
/// Combine two valid bounding rectangles. Inputs are validated before use.
pub fn Bounds::union(self : Bounds, other : Bounds) -> Bounds raise ShapeError {
  self.validate()
  other.validate()
  {
    xmin: if self.xmin < other.xmin {
      self.xmin
    } else {
      other.xmin
    },
    ymin: if self.ymin < other.ymin {
      self.ymin
    } else {
      other.ymin
    },
    xmax: if self.xmax > other.xmax {
      self.xmax
    } else {
      other.xmax
    },
    ymax: if self.ymax > other.ymax {
      self.ymax
    } else {
      other.ymax
    },
  }
}

///|
/// Intersection can be a zero-width/height rectangle when boundaries touch.
pub fn Bounds::intersection(
  self : Bounds,
  other : Bounds,
) -> Bounds? raise ShapeError {
  self.validate()
  other.validate()
  if !self.intersects(other) {
    return None
  }
  Some({
    xmin: if self.xmin > other.xmin {
      self.xmin
    } else {
      other.xmin
    },
    ymin: if self.ymin > other.ymin {
      self.ymin
    } else {
      other.ymin
    },
    xmax: if self.xmax < other.xmax {
      self.xmax
    } else {
      other.xmax
    },
    ymax: if self.ymax < other.ymax {
      self.ymax
    } else {
      other.ymax
    },
  })
}

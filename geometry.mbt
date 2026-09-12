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

pub(all) struct Coordinate {
  x : Double
  y : Double
  z : Double?
  m : Double?
} derive(Debug, Eq)

pub(all) struct Shape {
  kind : ShapeType
  points : Array[Coordinate]
  parts : Array[Int]
} derive(Debug, Eq)

pub(all) struct Bounds {
  xmin : Double
  ymin : Double
  xmax : Double
  ymax : Double
} derive(Debug, Eq)

pub fn coordinate(x : Double, y : Double, z? : Double, m? : Double) -> Coordinate {
  { x, y, z, m }
}

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

pub fn ShapeType::has_z(self : ShapeType) -> Bool {
  self is PointZ || self is PolyLineZ || self is PolygonZ || self is MultiPointZ
}

pub fn ShapeType::has_m(self : ShapeType) -> Bool {
  self.has_z() || self is PointM || self is PolyLineM || self is PolygonM || self is MultiPointM
}

pub fn ShapeType::is_point(self : ShapeType) -> Bool {
  self is Point || self is PointZ || self is PointM
}

pub fn ShapeType::is_multi(self : ShapeType) -> Bool {
  self is MultiPoint || self is MultiPointZ || self is MultiPointM
}

pub fn ShapeType::is_polygon(self : ShapeType) -> Bool {
  self is Polygon || self is PolygonZ || self is PolygonM
}

pub fn ShapeType::is_line(self : ShapeType) -> Bool {
  self is PolyLine || self is PolyLineZ || self is PolyLineM
}

pub fn Bounds::validate(self : Bounds) -> Unit raise ShapeError {
  if !finite(self.xmin) || !finite(self.ymin) || !finite(self.xmax) || !finite(self.ymax) {
    raise InvalidData(0, "nonfinite bounds")
  }
  if self.xmin > self.xmax || self.ymin > self.ymax {
    raise InvalidData(0, "reversed bounds")
  }
}

pub fn Bounds::contains(self : Bounds, point : Coordinate) -> Bool {
  point.x >= self.xmin && point.x <= self.xmax && point.y >= self.ymin && point.y <= self.ymax
}

pub fn Bounds::intersects(self : Bounds, other : Bounds) -> Bool {
  self.xmin <= other.xmax && self.xmax >= other.xmin && self.ymin <= other.ymax && self.ymax >= other.ymin
}

pub fn Shape::bounds(self : Shape) -> Bounds? {
  if self.points.is_empty() { return None }
  let p = self.points[0]
  let mut xmin = p.x
  let mut xmax = p.x
  let mut ymin = p.y
  let mut ymax = p.y
  for p in self.points {
    if p.x < xmin { xmin = p.x }
    if p.x > xmax { xmax = p.x }
    if p.y < ymin { ymin = p.y }
    if p.y > ymax { ymax = p.y }
  }
  Some({ xmin, ymin, xmax, ymax })
}

fn same_xy(a : Coordinate, b : Coordinate) -> Bool {
  a.x == b.x && a.y == b.y
}

fn Shape::part_end(self : Shape, part : Int) -> Int {
  if part + 1 < self.parts.length() { self.parts[part + 1] } else { self.points.length() }
}

pub fn Shape::validate(self : Shape) -> Unit raise ShapeError {
  if self.kind == Null {
    if !self.points.is_empty() || !self.parts.is_empty() {
      raise InvalidData(0, "null shape must be empty")
    }
    return
  }
  if self.points.is_empty() { raise InvalidData(0, "non-null shape has no points") }
  for i = 0; i < self.points.length(); i = i + 1 {
    let p = self.points[i]
    if !finite(p.x) || !finite(p.y) { raise InvalidData(i, "nonfinite XY coordinate") }
    match p.z {
      Some(z) => {
        if !finite(z) { raise InvalidData(i, "nonfinite Z coordinate") }
        if !self.kind.has_z() { raise InvalidData(i, "Z coordinate on non-Z shape") }
      }
      None => if self.kind.has_z() { raise InvalidData(i, "missing Z coordinate") }
    }
    match p.m {
      Some(m) => {
        if !finite(m) { raise InvalidData(i, "nonfinite measure") }
        if !self.kind.has_m() { raise InvalidData(i, "measure on XY shape") }
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
    if !self.parts.is_empty() { raise InvalidData(0, "multipoint cannot contain parts") }
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
    if end - start < minimum { raise InvalidData(i, "part has too few points") }
    if self.kind.is_polygon() && !same_xy(self.points[start], self.points[end - 1]) {
      raise InvalidData(i, "polygon ring is not closed")
    }
    for j = start + 1; j < end; j = j + 1 {
      if same_xy(self.points[j - 1], self.points[j]) {
        raise InvalidData(j, "zero-length segment")
      }
    }
  }
}

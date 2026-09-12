///|
fn coordinate_json(p : Coordinate) -> Json {
  let values = [Json::number(p.x), Json::number(p.y)]
  if p.z is Some(z) {
    values.push(Json::number(z))
  }
  Json::array(values)
}

///|
fn geometry_json(name : String, coordinates : Array[Json]) -> Json {
  Json::object({
    "type": Json::string(name),
    "coordinates": Json::array(coordinates),
  })
}

///|
/// Signed cross product with explicit overflow detection. Coordinates remain
/// unrounded: near-collinear input is never silently snapped to a grid.
fn orientation(
  a : Coordinate,
  b : Coordinate,
  c : Coordinate,
) -> Double raise ShapeError {
  let value = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
  if !finite(value) {
    raise InvalidData(0, "coordinate range overflows topology arithmetic")
  }
  value
}

///|
fn between(value : Double, a : Double, b : Double) -> Bool {
  (a <= value && value <= b) || (b <= value && value <= a)
}

///|
fn on_segment(
  p : Coordinate,
  a : Coordinate,
  b : Coordinate,
) -> Bool raise ShapeError {
  orientation(a, b, p) == 0.0 &&
  between(p.x, a.x, b.x) &&
  between(p.y, a.y, b.y)
}

///|
fn opposite(a : Double, b : Double) -> Bool {
  (a < 0.0 && b > 0.0) || (a > 0.0 && b < 0.0)
}

///|
fn segments_intersect(
  a : Coordinate,
  b : Coordinate,
  c : Coordinate,
  d : Coordinate,
) -> Bool raise ShapeError {
  let ab_c = orientation(a, b, c)
  let ab_d = orientation(a, b, d)
  let cd_a = orientation(c, d, a)
  let cd_b = orientation(c, d, b)
  if opposite(ab_c, ab_d) && opposite(cd_a, cd_b) {
    return true
  }
  (ab_c == 0.0 && on_segment(c, a, b)) ||
  (ab_d == 0.0 && on_segment(d, a, b)) ||
  (cd_a == 0.0 && on_segment(a, c, d)) ||
  (cd_b == 0.0 && on_segment(b, c, d))
}

///|
fn Shape::ring_area(self : Shape, part : Int) -> Double raise ShapeError {
  let start = self.parts[part]
  let end = self.part_end(part)
  let origin = self.points[start]
  let mut area = 0.0
  for i = start + 1; i + 1 < end; i = i + 1 {
    area += orientation(origin, self.points[i], self.points[i + 1])
    if !finite(area) {
      raise InvalidData(part, "polygon area overflows")
    }
  }
  if area == 0.0 {
    raise InvalidData(part, "zero-area polygon ring")
  }
  area
}

///|
/// Ray crossing uses orientation comparisons to avoid division by a tiny slope.
fn Shape::ring_contains(
  self : Shape,
  part : Int,
  point : Coordinate,
) -> Bool raise ShapeError {
  let mut inside = false
  for i = self.parts[part]; i + 1 < self.part_end(part); i = i + 1 {
    let a = self.points[i]
    let b = self.points[i + 1]
    if (a.y > point.y) != (b.y > point.y) {
      let cross = orientation(a, b, point)
      if (b.y > a.y && cross > 0.0) || (b.y < a.y && cross < 0.0) {
        inside = !inside
      }
    }
  }
  inside
}

///|
/// A fixed segment-comparison budget prevents adversarial quadratic work.
/// Exhaustion reports an error rather than exporting an unchecked polygon.
fn Shape::polygon_parents(self : Shape) -> Array[Int] raise ShapeError {
  let count = self.parts.length()
  let mut budget = 2000000
  for r = 0; r < count; r = r + 1 {
    let start = self.parts[r]
    let end = self.part_end(r)
    ignore(self.ring_area(r))
    // Adjacent edges may share their common endpoint, but cannot backtrack.
    for i = start; i + 1 < end; i = i + 1 {
      let next = if i + 2 < end { i + 2 } else { start + 1 }
      let a = self.points[i]
      let b = self.points[i + 1]
      let c = self.points[next]
      if orientation(a, b, c) == 0.0 &&
        (on_segment(c, a, b) || on_segment(a, b, c)) {
        raise InvalidData(r, "adjacent polygon edges overlap")
      }
    }
    for s = r; s < count; s = s + 1 {
      for i = start; i + 1 < end; i = i + 1 {
        let first = if r == s { i + 1 } else { self.parts[s] }
        for j = first; j + 1 < self.part_end(s); j = j + 1 {
          if r == s && (j == i + 1 || (i == start && j == end - 2)) {
            continue
          }
          budget -= 1
          if budget < 0 {
            raise InvalidData(r, "polygon topology work limit exceeded")
          }
          if segments_intersect(
              self.points[i],
              self.points[i + 1],
              self.points[j],
              self.points[j + 1],
            ) {
            raise InvalidData(r, "polygon rings cross, touch, or overlap")
          }
        }
      }
    }
  }
  let parents = Array::make(count, -1)
  let areas = Array::make(count, 0.0)
  for r = 0; r < count; r = r + 1 {
    let area = self.ring_area(r)
    areas[r] = if area < 0.0 { -area } else { area }
  }
  for r = 0; r < count; r = r + 1 {
    let point = self.points[self.parts[r]]
    for s = 0; s < count; s = s + 1 {
      if r == s {
        continue
      }
      budget -= self.part_end(s) - self.parts[s]
      if budget < 0 {
        raise InvalidData(r, "polygon containment work limit exceeded")
      }
      if self.ring_contains(s, point) {
        if areas[s] <= areas[r] {
          raise InvalidData(r, "inconsistent polygon nesting")
        }
        if parents[r] == -1 || areas[s] < areas[parents[r]] {
          parents[r] = s
        }
      }
    }
  }
  parents
}

///|
fn Shape::part_json(self : Shape, part : Int, reverse : Bool) -> Json {
  let result : Array[Json] = []
  if reverse {
    for i = self.part_end(part) - 1; i >= self.parts[part]; i = i - 1 {
      result.push(coordinate_json(self.points[i]))
    }
  } else {
    for i = self.parts[part]; i < self.part_end(part); i = i + 1 {
      result.push(coordinate_json(self.points[i]))
    }
  }
  Json::array(result)
}

///|
/// Export a geometry object. Input is longitude/latitude by default; the opt-in
/// permits projected output without claiming RFC 7946 coordinate compliance.
/// M is omitted, and Z is retained. Polygon rings may arrive in any order or
/// winding; nesting determines shell/hole roles, including islands in holes.
pub fn Shape::to_geojson(
  self : Shape,
  allow_projected? : Bool = false,
) -> Json raise ShapeError {
  self.validate()
  if self.kind == Null {
    return Json::null()
  }
  if !allow_projected {
    for i = 0; i < self.points.length(); i = i + 1 {
      let p = self.points[i]
      if p.x < -180.0 || p.x > 180.0 || p.y < -90.0 || p.y > 90.0 {
        raise InvalidData(
          i, "GeoJSON requires longitude/latitude or allow_projected=true",
        )
      }
    }
  }
  if self.kind.is_point() {
    return Json::object({
      "type": Json::string("Point"),
      "coordinates": coordinate_json(self.points[0]),
    })
  }
  if self.kind.is_multi() {
    return geometry_json("MultiPoint", self.points.map(coordinate_json))
  }
  if self.kind.is_line() {
    if self.parts.length() == 1 {
      return Json::object({
        "type": Json::string("LineString"),
        "coordinates": self.part_json(0, false),
      })
    }
    let parts : Array[Json] = []
    for i = 0; i < self.parts.length(); i = i + 1 {
      parts.push(self.part_json(i, false))
    }
    return geometry_json("MultiLineString", parts)
  }
  let parents = self.polygon_parents()
  let depth = Array::make(parents.length(), 0)
  for i = 0; i < parents.length(); i = i + 1 {
    let mut parent = parents[i]
    while parent != -1 {
      depth[i] += 1
      if depth[i] > parents.length() {
        raise InvalidData(i, "cyclic polygon nesting")
      }
      parent = parents[parent]
    }
  }
  let polygons : Array[Json] = []
  for i = 0; i < parents.length(); i = i + 1 {
    if depth[i] % 2 != 0 {
      continue
    }
    let rings = [self.part_json(i, self.ring_area(i) < 0.0)]
    for j = 0; j < parents.length(); j = j + 1 {
      if parents[j] == i {
        rings.push(self.part_json(j, self.ring_area(j) > 0.0))
      }
    }
    polygons.push(Json::array(rings))
  }
  if polygons.length() == 1 {
    Json::object({ "type": Json::string("Polygon"), "coordinates": polygons[0] })
  } else {
    geometry_json("MultiPolygon", polygons)
  }
}

///|
fn json_array(value : Json, context : String) -> Array[Json] raise ShapeError {
  match value {
    Array(items) => items
    _ => raise InvalidData(0, context + " must be an array")
  }
}

///|
fn json_coordinate(
  value : Json,
  kind : ShapeType,
) -> Coordinate raise ShapeError {
  let items = json_array(value, "position")
  let expected = if kind.has_z() { 3 } else { 2 }
  if items.length() != expected {
    raise InvalidData(
      0, "position dimension does not match requested shape type",
    )
  }
  let values : Array[Double] = []
  for item in items {
    match item {
      Number(n, ..) => {
        if !finite(n) {
          raise InvalidData(0, "nonfinite GeoJSON coordinate")
        }
        values.push(n)
      }
      _ => raise InvalidData(0, "coordinate must be a number")
    }
  }
  {
    x: values[0],
    y: values[1],
    z: if expected == 3 {
      Some(values[2])
    } else {
      None
    },
    m: None,
  }
}

///|
fn append_json_positions(
  value : Json,
  kind : ShapeType,
  points : Array[Coordinate],
) -> Unit raise ShapeError {
  let items = json_array(value, "coordinate sequence")
  if items.is_empty() {
    raise InvalidData(0, "empty coordinate sequence")
  }
  if items.length() > 1000000 - points.length() {
    raise InvalidData(0, "GeoJSON coordinate limit exceeded")
  }
  for item in items {
    points.push(json_coordinate(item, kind))
  }
}

///|
fn append_json_parts(
  value : Json,
  kind : ShapeType,
  points : Array[Coordinate],
  parts : Array[Int],
) -> Unit raise ShapeError {
  let items = json_array(value, "parts")
  if items.is_empty() {
    raise InvalidData(0, "empty geometry parts")
  }
  for item in items {
    parts.push(points.length())
    append_json_positions(item, kind, points)
  }
}

///|
/// Import a GeoJSON geometry into an explicit ESRI shape type. Two ordinates
/// are required for XY/M types, three for Z types. Measures remain absent.
/// Feature wrappers and collections must be handled by the dataset layer.
/// Coordinates are preserved without reprojection or longitude wrapping.
pub fn shape_from_geojson(
  value : Json,
  kind : ShapeType,
) -> Shape raise ShapeError {
  if value is Null {
    return { kind: Null, points: [], parts: [] }
  }
  let object = match value {
    Object(object) => object
    _ => raise InvalidData(0, "GeoJSON geometry must be an object or null")
  }
  let name = match object.get("type") {
    Some(String(name)) => name
    _ => raise InvalidData(0, "GeoJSON geometry is missing string type")
  }
  let coordinates = match object.get("coordinates") {
    Some(value) => value
    None => raise InvalidData(0, "GeoJSON geometry is missing coordinates")
  }
  let points : Array[Coordinate] = []
  let parts : Array[Int] = []
  // Preserve component identity long enough to reject a MultiPolygon whose
  // supposed exterior is actually nested inside another component.
  let exterior_parts : Array[Int] = []
  let expected_parent : Array[Int] = []
  match name {
    "Point" => {
      if !kind.is_point() {
        raise InvalidData(0, "Point target type mismatch")
      }
      points.push(json_coordinate(coordinates, kind))
    }
    "MultiPoint" => {
      if !kind.is_multi() {
        raise InvalidData(0, "MultiPoint target type mismatch")
      }
      append_json_positions(coordinates, kind, points)
    }
    "LineString" => {
      if !kind.is_line() {
        raise InvalidData(0, "LineString target type mismatch")
      }
      parts.push(0)
      append_json_positions(coordinates, kind, points)
    }
    "MultiLineString" => {
      if !kind.is_line() {
        raise InvalidData(0, "MultiLineString target type mismatch")
      }
      append_json_parts(coordinates, kind, points, parts)
    }
    "Polygon" => {
      if !kind.is_polygon() {
        raise InvalidData(0, "Polygon target type mismatch")
      }
      append_json_parts(coordinates, kind, points, parts)
      exterior_parts.push(0)
      for i = 0; i < parts.length(); i = i + 1 {
        expected_parent.push(if i == 0 { -1 } else { 0 })
      }
    }
    "MultiPolygon" => {
      if !kind.is_polygon() {
        raise InvalidData(0, "MultiPolygon target type mismatch")
      }
      let polygons = json_array(coordinates, "polygons")
      if polygons.is_empty() {
        raise InvalidData(0, "empty MultiPolygon")
      }
      for polygon in polygons {
        let exterior = parts.length()
        exterior_parts.push(exterior)
        append_json_parts(polygon, kind, points, parts)
        for i = exterior; i < parts.length(); i = i + 1 {
          expected_parent.push(if i == exterior { -1 } else { exterior })
        }
      }
    }
    _ => raise InvalidData(0, "unsupported GeoJSON geometry type")
  }
  let result : Shape = { kind, points, parts }
  result.validate()
  if kind.is_polygon() {
    let parents = result.polygon_parents()
    for i = 0; i < parts.length(); i = i + 1 {
      if expected_parent[i] >= 0 {
        if parents[i] != expected_parent[i] {
          raise InvalidData(
            i, "GeoJSON hole lies outside its exterior or inside another hole",
          )
        }
        // An exterior can be an island in another polygon's hole, but cannot
        // be directly contained in another exterior (overlapping polygons).
      } else if parents[i] >= 0 && expected_parent[parents[i]] == -1 {
        raise InvalidData(i, "GeoJSON polygon interiors overlap")
      }
    }
    for i = 0; i < parts.length(); i = i + 1 {
      let is_shell = expected_parent[i] == -1
      let area = result.ring_area(i)
      if (is_shell && area > 0.0) || (!is_shell && area < 0.0) {
        let mut left = parts[i]
        let mut right = result.part_end(i) - 1
        while left < right {
          let tmp = points[left]
          points[left] = points[right]
          points[right] = tmp
          left += 1
          right -= 1
        }
      }
    }
  }
  result
}

/// Matching SHP and SHX byte streams, ready for filesystem or network storage.
pub(all) struct ShapeFiles {
  shp : Bytes
  shx : Bytes
} derive(Debug)

fn bounds_bytes(w : ByteWriter, bounds : Bounds?) -> Unit {
  match bounds {
    Some(b) => {
      w.f64(b.xmin)
      w.f64(b.ymin)
      w.f64(b.xmax)
      w.f64(b.ymax)
    }
    None => for _ in 0..<4 { w.f64(0.0) }
  }
}

fn extend_range(range : (Double, Double)?, value : Double?) -> (Double, Double)? {
  match (range, value) {
    (r, None) => r
    (None, Some(v)) => Some((v, v))
    (Some((a, b)), Some(v)) => Some((if v < a { v } else { a }, if v > b { v } else { b }))
  }
}

fn ordinate_range(points : Array[Coordinate], z : Bool) -> (Double, Double)? {
  let mut range = None
  for p in points {
    range = extend_range(range, if z { p.z } else { p.m })
  }
  range
}

fn write_ordinates(w : ByteWriter, points : Array[Coordinate], z : Bool) -> Unit {
  let range = ordinate_range(points, z)
  match range {
    Some((lo, hi)) => { w.f64(lo); w.f64(hi) }
    None => { w.f64(-1.0e39); w.f64(-1.0e39) }
  }
  for p in points {
    w.f64((if z { p.z } else { p.m }).unwrap_or(-1.0e39))
  }
}

fn encode_shape(shape : Shape) -> Bytes raise ShapeError {
  shape.validate()
  let w = ByteWriter::new()
  w.le32(shape.kind.code())
  if shape.kind == Null { return w.bytes() }
  if shape.kind.is_point() {
    let p = shape.points[0]
    w.f64(p.x)
    w.f64(p.y)
    if shape.kind.has_z() { w.f64(p.z.unwrap()) }
    if shape.kind.has_m() { w.f64(p.m.unwrap_or(-1.0e39)) }
  } else {
    bounds_bytes(w, shape.bounds())
    if shape.kind.is_line() || shape.kind.is_polygon() {
      w.le32(shape.parts.length())
    }
    w.le32(shape.points.length())
    for part in shape.parts { w.le32(part) }
    for p in shape.points { w.f64(p.x); w.f64(p.y) }
    if shape.kind.has_z() { write_ordinates(w, shape.points, true) }
    if shape.kind.has_m() { write_ordinates(w, shape.points, false) }
  }
  w.bytes()
}

/// Accumulates encoded records; append validates a record before mutation.
pub struct ShpWriter {
  kind : ShapeType
  limits : ReadLimits
  records : Array[Bytes]
  mut total_bytes : Int
  mut bounds : Bounds?
  mut zrange : (Double, Double)?
  mut mrange : (Double, Double)?
}

pub fn ShpWriter::new(kind : ShapeType, limits? : ReadLimits = ReadLimits::default()) -> ShpWriter raise ShapeError {
  limits.validate()
  {
    kind, limits, records: [], total_bytes: 100,
    bounds: None, zrange: None, mrange: None,
  }
}

pub fn ShpWriter::record_count(self : ShpWriter) -> Int {
  self.records.length()
}

pub fn ShpWriter::append(self : ShpWriter, shape : Shape) -> Unit raise ShapeError {
  if shape.kind != Null && shape.kind != self.kind {
    raise InvalidData(self.records.length(), "shape type differs from writer type")
  }
  if self.records.length() >= self.limits.max_records {
    raise InvalidData(self.records.length(), "writer record limit exceeded")
  }
  if shape.points.length() > self.limits.max_points_per_record ||
    shape.parts.length() > self.limits.max_parts_per_record {
    raise InvalidData(self.records.length(), "writer geometry limit exceeded")
  }
  // Bound the eventual body size before encoding arrays.
  let point_width = if shape.kind.has_z() { 32 } else if shape.kind.has_m() { 24 } else { 16 }
  let available = self.limits.max_file_bytes - self.total_bytes
  if available < 12 || shape.points.length() > available / point_width ||
    shape.parts.length() > available / 4 {
    raise InvalidData(self.total_bytes, "writer byte limit exceeded")
  }
  let body = encode_shape(shape)
  if body.length() > available - 8 {
    raise InvalidData(self.total_bytes, "writer byte limit exceeded")
  }
  self.records.push(body)
  self.total_bytes += 8 + body.length()
  self.bounds = merge_bounds(self.bounds, shape.bounds())
  for p in shape.points {
    self.zrange = extend_range(self.zrange, p.z)
    self.mrange = extend_range(self.mrange, p.m)
  }
}

/// Finishing is repeatable and does not consume the writer.
pub fn ShpWriter::finish(self : ShpWriter) -> ShapeFiles {
  let shp = ByteWriter::new()
  let shx = ByteWriter::new()
  shp.append(write_header(self.total_bytes, self.kind, self.bounds, self.zrange, self.mrange))
  shx.append(write_header(100 + self.records.length() * 8, self.kind, self.bounds, self.zrange, self.mrange))
  let mut offset = 100
  for i in 0..<self.records.length() {
    let body = self.records[i]
    shp.be32(i + 1)
    shp.be32(body.length() / 2)
    shp.append(body)
    shx.be32(offset / 2)
    shx.be32(body.length() / 2)
    offset += 8 + body.length()
  }
  { shp: shp.bytes(), shx: shx.bytes() }
}

pub fn write_shp(kind : ShapeType, shapes : Array[Shape], limits? : ReadLimits = ReadLimits::default()) -> ShapeFiles raise ShapeError {
  let writer = ShpWriter::new(kind, limits~)
  for shape in shapes { writer.append(shape) }
  writer.finish()
}

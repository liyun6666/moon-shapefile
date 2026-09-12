pub(all) struct Record {
  number : Int
  offset : Int
  content_length : Int
  shape : Shape
} derive(Debug)

pub(all) struct Shapefile {
  kind : ShapeType
  records : Array[Record]
  bounds : Bounds?
} derive(Debug)

/// Cursor holds original bytes and decodes one record at a time.
pub struct ShpReader {
  data : Bytes
  header : Header
  limits : ReadLimits
  mut position : Int
  mut count : Int
}

pub fn ShpReader::open(data : Bytes, limits? : ReadLimits = ReadLimits::default()) -> ShpReader raise ShapeError {
  limits.validate()
  if data.length() > limits.max_file_bytes {
    raise InvalidData(0, "file exceeds configured byte limit")
  }
  let header = read_header(data)
  { data, header, limits, position: 100, count: 0 }
}

pub fn ShpReader::header(self : ShpReader) -> Header {
  self.header
}

pub fn ShpReader::position(self : ShpReader) -> Int {
  self.position
}

/// A failed decode does not advance the cursor.
pub fn ShpReader::next(self : ShpReader) -> Record? raise ShapeError {
  if self.position == self.data.length() { return None }
  if self.count >= self.limits.max_records {
    raise InvalidData(self.position, "record count exceeds configured limit")
  }
  let r : ByteReader = { data: self.data, pos: self.position, end: self.data.length(), base: 0 }
  let number = r.be32()
  if number != self.count + 1 {
    raise InvalidData(self.position, "record numbers must be consecutive starting at one")
  }
  let content_length = words_to_bytes(r.be32(), self.position + 4)
  let body = r.take(content_length)
  let shape = decode_shape(body, self.position + 8, self.limits)
  if shape.kind != Null && shape.kind != self.header.kind {
    raise InvalidData(self.position + 8, "record shape type differs from file type")
  }
  match shape.bounds() {
    Some(b) => {
      if b.xmin < self.header.bounds.xmin || b.ymin < self.header.bounds.ymin ||
        b.xmax > self.header.bounds.xmax || b.ymax > self.header.bounds.ymax {
        raise InvalidData(self.position + 8, "record geometry lies outside file bounds")
      }
    }
    None => ()
  }
  if shape.kind.has_z() {
    for p in shape.points {
      match p.z {
        Some(z) => if z < self.header.zmin || z > self.header.zmax { raise InvalidData(self.position + 8, "Z outside file bounds") }
        None => ()
      }
    }
  }
  let record = { number, offset: self.position, content_length, shape }
  self.position += 8 + content_length
  self.count += 1
  Some(record)
}

pub fn read_shp(data : Bytes, limits? : ReadLimits = ReadLimits::default()) -> Shapefile raise ShapeError {
  let reader = ShpReader::open(data, limits~)
  let records : Array[Record] = []
  let mut bounds : Bounds? = None
  while true {
    match reader.next() {
      None => break
      Some(record) => {
        bounds = merge_bounds(bounds, record.shape.bounds())
        records.push(record)
      }
    }
  }
  { kind: reader.header.kind, records, bounds }
}

fn merge_bounds(a : Bounds?, b : Bounds?) -> Bounds? {
  match (a, b) {
    (None, b) => b
    (a, None) => a
    (Some(a), Some(b)) => Some({
      xmin: @cmp.minimum(a.xmin, b.xmin),
      ymin: @cmp.minimum(a.ymin, b.ymin),
      xmax: @cmp.maximum(a.xmax, b.xmax),
      ymax: @cmp.maximum(a.ymax, b.ymax),
    })
  }
}

fn read_bbox(r : ByteReader) -> Bounds raise ShapeError {
  let xmin = r.f64()
  let ymin = r.f64()
  let xmax = r.f64()
  let ymax = r.f64()
  let b : Bounds = { xmin, ymin, xmax, ymax }
  b.validate()
  b
}

fn read_xy(r : ByteReader, count : Int) -> Array[Coordinate] raise ShapeError {
  ignore(checked_size(count, 16, r.remaining(), r.base + r.pos))
  let points : Array[Coordinate] = []
  for _ in 0..<count {
    let x = r.f64()
    let y = r.f64()
    if !finite(x) || !finite(y) {
      raise InvalidData(r.base + r.pos - 16, "nonfinite XY coordinate")
    }
    points.push({ x, y, z: None, m: None })
  }
  points
}

fn read_z_array(r : ByteReader, points : Array[Coordinate]) -> Unit raise ShapeError {
  let lo = r.f64()
  let hi = r.f64()
  if !finite(lo) || !finite(hi) || lo > hi {
    raise InvalidData(r.base + r.pos - 16, "invalid Z range")
  }
  ignore(checked_size(points.length(), 8, r.remaining(), r.base + r.pos))
  for i in 0..<points.length() {
    let z = r.f64()
    if !finite(z) || z < lo || z > hi {
      raise InvalidData(r.base + r.pos - 8, "Z coordinate outside declared range")
    }
    let p = points[i]
    points[i] = { x: p.x, y: p.y, z: Some(z), m: p.m }
  }
}

fn measure(value : Double, offset : Int) -> Double? raise ShapeError {
  if !finite(value) { raise InvalidData(offset, "nonfinite measure") }
  if value < -1.0e38 { None } else { Some(value) }
}

fn read_m_array(r : ByteReader, points : Array[Coordinate]) -> Unit raise ShapeError {
  // ESRI permits the entire M range/array to be absent in multipart M/Z records.
  if r.remaining() == 0 { return }
  let lo = measure(r.f64(), r.base + r.pos - 8)
  let hi = measure(r.f64(), r.base + r.pos - 8)
  match (lo, hi) {
    (Some(lo), Some(hi)) => if lo > hi {
      raise InvalidData(r.base + r.pos - 16, "reversed M range")
    }
    (None, None) => ()
    _ => raise InvalidData(r.base + r.pos - 16, "inconsistent no-data M range")
  }
  ignore(checked_size(points.length(), 8, r.remaining(), r.base + r.pos))
  for i in 0..<points.length() {
    let m = measure(r.f64(), r.base + r.pos - 8)
    match (m, lo, hi) {
      (Some(v), Some(a), Some(b)) => if v < a || v > b {
        raise InvalidData(r.base + r.pos - 8, "measure outside declared range")
      }
      (Some(_), _, _) => raise InvalidData(r.base + r.pos - 8, "measure has no declared range")
      _ => ()
    }
    let p = points[i]
    points[i] = { x: p.x, y: p.y, z: p.z, m }
  }
}

fn decode_shape(data : Bytes, base : Int, limits : ReadLimits) -> Shape raise ShapeError {
  let r = ByteReader::new(data, base~)
  let kind = shape_type(r.le32())
  let points : Array[Coordinate] = []
  let parts : Array[Int] = []
  let mut declared_bounds : Bounds? = None
  if kind.is_point() {
    if limits.max_points_per_record < 1 {
      raise InvalidData(base + r.pos, "point count exceeds configured limit")
    }
    let x = r.f64()
    let y = r.f64()
    let z = if kind.has_z() { Some(r.f64()) } else { None }
    let m = if kind.has_m() && r.remaining() > 0 {
      measure(r.f64(), base + r.pos - 8)
    } else { None }
    if kind == PointM && m is None && data.length() == 20 {
      raise InvalidData(base + 20, "PointM requires measure bytes")
    }
    points.push({ x, y, z, m })
  } else if kind != Null {
    declared_bounds = Some(read_bbox(r))
    let part_count = if kind.is_line() || kind.is_polygon() { r.le32() } else { 0 }
    let point_count = r.le32()
    if point_count < 0 || point_count > limits.max_points_per_record {
      raise InvalidData(base + r.pos - 4, "point count exceeds configured limit")
    }
    if part_count < 0 || part_count > limits.max_parts_per_record {
      raise InvalidData(base + 36, "part count exceeds configured limit")
    }
    ignore(checked_size(part_count, 4, r.remaining(), base + r.pos))
    for _ in 0..<part_count { parts.push(r.le32()) }
    for p in read_xy(r, point_count) { points.push(p) }
    if kind.has_z() { read_z_array(r, points) }
    if kind.has_m() { read_m_array(r, points) }
  }
  if r.remaining() != 0 {
    raise InvalidData(base + r.pos, "unexpected trailing record bytes")
  }
  let shape : Shape = { kind, points, parts }
  shape.validate()
  match (declared_bounds, shape.bounds()) {
    (Some(a), Some(b)) => if b.xmin < a.xmin || b.ymin < a.ymin ||
      b.xmax > a.xmax || b.ymax > a.ymax {
      raise InvalidData(base + 4, "geometry exceeds record bounds")
    }
    _ => ()
  }
  shape
}

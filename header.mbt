///|
/// Parsed file header; ranges remain available for inspection.
pub(all) struct Header {
  file_length : Int
  kind : ShapeType
  bounds : Bounds
  zmin : Double
  zmax : Double
  mmin : Double
  mmax : Double
} derive(Debug)

///|
/// Resource limits apply before allocating point or record arrays.
pub(all) struct ReadLimits {
  max_records : Int
  max_points_per_record : Int
  max_parts_per_record : Int
  max_file_bytes : Int
} derive(Debug)

///|
pub fn ReadLimits::default() -> ReadLimits {
  {
    max_records: 1000000,
    max_points_per_record: 1000000,
    max_parts_per_record: 100000,
    max_file_bytes: 536870912,
  }
}

///|
fn ReadLimits::validate(self : ReadLimits) -> Unit raise ShapeError {
  if self.max_records < 0 ||
    self.max_points_per_record < 0 ||
    self.max_parts_per_record < 0 ||
    self.max_file_bytes < 100 {
    raise InvalidData(0, "invalid resource limits")
  }
}

///|
/// Read and verify the 100-byte header. Full file bytes are required.
pub fn read_header(data : Bytes) -> Header raise ShapeError {
  let r = ByteReader::new(data)
  r.require(100)
  if r.be32() != 9994 {
    raise InvalidData(0, "invalid Shapefile magic")
  }
  for _ in 0..<5 {
    if r.be32() != 0 {
      raise InvalidData(r.pos - 4, "reserved header word must be zero")
    }
  }
  let file_length = words_to_bytes(r.be32(), 24)
  if file_length != data.length() {
    raise InvalidData(24, "declared file length differs from actual bytes")
  }
  if r.le32() != 1000 {
    raise InvalidData(28, "unsupported Shapefile version")
  }
  let kind = shape_type(r.le32())
  let xmin = r.f64()
  let ymin = r.f64()
  let xmax = r.f64()
  let ymax = r.f64()
  let bounds : Bounds = { xmin, ymin, xmax, ymax }
  bounds.validate()
  let zmin = r.f64()
  let zmax = r.f64()
  let mmin = r.f64()
  let mmax = r.f64()
  if !finite(zmin) || !finite(zmax) || !finite(mmin) || !finite(mmax) {
    raise InvalidData(68, "nonfinite range in header")
  }
  if kind.has_z() && zmin > zmax {
    raise InvalidData(68, "reversed Z range")
  }
  if kind.has_m() && mmin >= -1.0e38 && mmax >= -1.0e38 && mmin > mmax {
    raise InvalidData(84, "reversed M range")
  }
  { file_length, kind, bounds, zmin, zmax, mmin, mmax }
}

///|
fn write_header(
  length : Int,
  kind : ShapeType,
  bounds : Bounds?,
  zrange : (Double, Double)?,
  mrange : (Double, Double)?,
) -> Bytes {
  let w = ByteWriter::new()
  w.be32(9994)
  for _ in 0..<5 {
    w.be32(0)
  }
  w.be32(length / 2)
  w.le32(1000)
  w.le32(kind.code())
  match bounds {
    Some(b) => {
      w.f64(b.xmin)
      w.f64(b.ymin)
      w.f64(b.xmax)
      w.f64(b.ymax)
    }
    None =>
      for _ in 0..<4 {
        w.f64(0.0)
      }
  }
  match zrange {
    Some((lo, hi)) => {
      w.f64(lo)
      w.f64(hi)
    }
    None => {
      w.f64(0.0)
      w.f64(0.0)
    }
  }
  match mrange {
    Some((lo, hi)) => {
      w.f64(lo)
      w.f64(hi)
    }
    None => {
      let no_data = if kind.has_m() { -1.0e39 } else { 0.0 }
      w.f64(no_data)
      w.f64(no_data)
    }
  }
  w.bytes()
}

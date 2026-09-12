// Hand-specified ESRI point record, independent of the SHP encoder.

///|
fn point_fixture() -> Bytes {
  let w = ByteWriter::new()
  w.be32(9994)
  for _ in 0..<5 {
    w.be32(0)
  }
  w.be32(64)
  w.le32(1000)
  w.le32(1)
  for n in [1.0, 2.0, 1.0, 2.0, 0.0, 0.0, 0.0, 0.0] {
    w.f64(n)
  }
  w.be32(1)
  w.be32(10)
  w.le32(1)
  w.f64(1.0)
  w.f64(2.0)
  w.bytes()
}

///|
test "reads point record from specified ESRI offsets" {
  let file = read_shp(point_fixture())
  assert_eq(file.records.length(), 1)
  assert_eq(file.records[0].offset, 100)
  assert_eq(file.records[0].content_length, 20)
  assert_eq(file.records[0].shape.points[0].x, 1.0)
  assert_eq(file.records[0].shape.points[0].y, 2.0)
}

///|
test "rejects header length different from actual file" {
  let data = point_fixture().to_array()
  data[27] = b'\x63'
  let rejected = try {
    ignore(read_shp(Bytes::from_array(data)))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "rejects truncated record without panic" {
  let fixture = point_fixture()
  let rejected = try {
    ignore(read_shp(fixture[:127].to_owned()))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "sequential reader yields same point and then eof" {
  let stream = ShpReader::open(point_fixture())
  assert_eq(stream.next().unwrap().number, 1)
  assert_true(stream.next() is None)
}

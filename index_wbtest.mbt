fn point_index_fixture() -> Bytes {
  let data = point_fixture().to_array()
  let header = Bytes::from_array(data[:100]) .to_array()
  header[27] = b'\x36'
  let w = ByteWriter::new()
  w.append(Bytes::from_array(header))
  w.be32(50)
  w.be32(10)
  w.bytes()
}

test "index offsets and lengths agree with SHP record boundaries" {
  validate_shx(point_fixture(), point_index_fixture())
}

test "index cannot point into record body" {
  let index = point_index_fixture().to_array()
  index[103] = b'\x36'
  let rejected = try {
    validate_shx(point_fixture(), Bytes::from_array(index))
    false
  } catch { _ => true }
  assert_true(rejected)
}

test "random record access rejects out of range" {
  let reader = IndexedReader::open(point_fixture(), point_index_fixture())
  assert_eq(reader.record_at(0).shape.points[0].y, 2.0)
  let rejected = try { ignore(reader.record_at(1)); false } catch { _ => true }
  assert_true(rejected)
}

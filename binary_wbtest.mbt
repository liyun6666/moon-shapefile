///|
test "mixed endian integers and IEEE double use file byte order" {
  let r = ByteReader::new(
    b"\x00\x00\x27\x0a\xe8\x03\x00\x00\x00\x00\x00\x00\x00\x00\xf0\x3f",
  )
  assert_eq(r.be32(), 9994)
  assert_eq(r.le32(), 1000)
  assert_eq(r.f64(), 1.0)
  assert_eq(r.remaining(), 0)
}

///|
test "truncated primitive reports an offset instead of indexing panic" {
  let result = ByteReader::new(b"\x01").le32() catch { _ => -1 }
  assert_eq(result, -1)
}

///|
test "writer emits independently specified header primitives" {
  let w = ByteWriter::new()
  w.be32(9994)
  w.le32(1000)
  w.f64(1.0)
  assert_eq(
    w.bytes(),
    b"\x00\x00\x27\x0a\xe8\x03\x00\x00\x00\x00\x00\x00\x00\x00\xf0\x3f",
  )
}

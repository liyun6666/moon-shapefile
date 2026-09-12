///|
/// Additional checked primitives used by DBF and index adapters.
fn ByteReader::le16(self : ByteReader) -> Int raise ShapeError {
  self.require(2)
  let p = self.pos
  self.pos += 2
  self.data[p].to_int() | (self.data[p + 1].to_int() << 8)
}

///|
fn ByteReader::be16(self : ByteReader) -> Int raise ShapeError {
  self.require(2)
  let p = self.pos
  self.pos += 2
  (self.data[p].to_int() << 8) | self.data[p + 1].to_int()
}

///|
fn ByteReader::u8(self : ByteReader) -> Int raise ShapeError {
  self.require(1)
  let value = self.data[self.pos].to_int()
  self.pos += 1
  value
}

///|
fn ByteWriter::le16(self : ByteWriter, n : Int) -> Unit {
  self.data.push(n.to_byte())
  self.data.push((n >> 8).to_byte())
}

///|
fn ByteWriter::be16(self : ByteWriter, n : Int) -> Unit {
  self.data.push((n >> 8).to_byte())
  self.data.push(n.to_byte())
}

///|
fn ByteWriter::u8(self : ByteWriter, n : Int) -> Unit {
  self.data.push(n.to_byte())
}

///|
fn crc32(data : Bytes) -> UInt {
  let mut crc : UInt = 0xffffffff
  for byte in data {
    crc = crc ^ byte.to_int().to_uint()
    for _ in 0..<8 {
      crc = if (crc & 1) != 0 { (crc >> 1) ^ 0xedb88320 } else { crc >> 1 }
    }
  }
  crc ^ 0xffffffff
}

///|
fn bytes_equal_at(data : Bytes, offset : Int, expected : Bytes) -> Bool {
  if offset < 0 || offset + expected.length() > data.length() {
    return false
  }
  for i in 0..<expected.length() {
    if data[offset + i] != expected[i] {
      return false
    }
  }
  true
}

///|
test "checked 16-bit primitives and CRC are deterministic" {
  let w = ByteWriter::new()
  w.le16(0x1234)
  w.be16(0xabcd)
  let bytes = w.bytes()
  let r = ByteReader::new(bytes)
  assert_eq(r.le16(), 0x1234)
  assert_eq(r.be16(), 0xabcd)
  assert_true(bytes_equal_at(bytes, 0, b"\x34\x12"))
  assert_eq(crc32(b"123456789"), 0xcbf43926)
}

/// Errors always identify the byte offset or logical record involved.
pub suberror ShapeError {
  InvalidData(Int, String)
} derive(Debug)

priv struct ByteReader {
  data : Bytes
  mut pos : Int
  end : Int
  base : Int
}

fn ByteReader::new(data : Bytes, base? : Int = 0) -> ByteReader {
  { data, pos: 0, end: data.length(), base }
}

fn ByteReader::remaining(self : ByteReader) -> Int {
  self.end - self.pos
}

fn ByteReader::require(self : ByteReader, n : Int) -> Unit raise ShapeError {
  if n < 0 || n > self.remaining() {
    raise InvalidData(self.base + self.pos, "truncated binary value")
  }
}

fn ByteReader::le32(self : ByteReader) -> Int raise ShapeError {
  self.require(4)
  let p = self.pos
  self.pos += 4
  self.data[p].to_int() | (self.data[p + 1].to_int() << 8) |
  (self.data[p + 2].to_int() << 16) | (self.data[p + 3].to_int() << 24)
}

fn ByteReader::be32(self : ByteReader) -> Int raise ShapeError {
  self.require(4)
  let p = self.pos
  self.pos += 4
  (self.data[p].to_int() << 24) | (self.data[p + 1].to_int() << 16) |
  (self.data[p + 2].to_int() << 8) | self.data[p + 3].to_int()
}

fn ByteReader::f64(self : ByteReader) -> Double raise ShapeError {
  self.require(8)
  let mut bits : UInt64 = 0
  for i = 0; i < 8; i = i + 1 {
    bits = bits | (self.data[self.pos + i].to_int().to_uint64() << (i * 8))
  }
  self.pos += 8
  bits.reinterpret_as_double()
}

fn ByteReader::take(self : ByteReader, n : Int) -> Bytes raise ShapeError {
  self.require(n)
  let result = self.data[self.pos:self.pos + n].to_owned()
  self.pos += n
  result
}

priv struct ByteWriter {
  data : Array[Byte]
}

fn ByteWriter::new() -> ByteWriter {
  { data: [] }
}

fn ByteWriter::le32(self : ByteWriter, n : Int) -> Unit {
  for i = 0; i < 4; i = i + 1 {
    self.data.push((n >> (i * 8)).to_byte())
  }
}

fn ByteWriter::be32(self : ByteWriter, n : Int) -> Unit {
  for i = 3; i >= 0; i = i - 1 {
    self.data.push((n >> (i * 8)).to_byte())
  }
}

fn ByteWriter::f64(self : ByteWriter, n : Double) -> Unit {
  let bits = n.reinterpret_as_uint64()
  for i = 0; i < 8; i = i + 1 {
    self.data.push((bits >> (i * 8)).to_byte())
  }
}

fn ByteWriter::append(self : ByteWriter, bytes : Bytes) -> Unit {
  for b in bytes {
    self.data.push(b)
  }
}

fn ByteWriter::bytes(self : ByteWriter) -> Bytes {
  Bytes::from_array(self.data)
}

fn finite(n : Double) -> Bool {
  !n.is_nan() && n <= 1.7976931348623157e308 && n >= -1.7976931348623157e308
}

fn checked_size(count : Int, width : Int, available : Int, offset : Int) -> Int raise ShapeError {
  if count < 0 || width <= 0 || count > available / width {
    raise InvalidData(offset, "count exceeds available bytes")
  }
  count * width
}

fn words_to_bytes(words : Int, offset : Int) -> Int raise ShapeError {
  if words < 0 || words > 1073741823 {
    raise InvalidData(offset, "invalid 16-bit word length")
  }
  words * 2
}

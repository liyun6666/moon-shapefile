pub(all) struct IndexEntry {
  offset : Int
  content_length : Int
} derive(Debug, Eq)

/// Decode SHX entries, checking contiguous byte boundaries from offset 100.
pub fn read_index(data : Bytes, limits? : ReadLimits = ReadLimits::default()) -> Array[IndexEntry] raise ShapeError {
  limits.validate()
  if data.length() > limits.max_file_bytes {
    raise InvalidData(0, "index exceeds configured byte limit")
  }
  ignore(read_header(data))
  if (data.length() - 100) % 8 != 0 {
    raise InvalidData(100, "SHX entry region must be a multiple of eight bytes")
  }
  let count = (data.length() - 100) / 8
  if count > limits.max_records {
    raise InvalidData(100, "index exceeds record limit")
  }
  let r : ByteReader = { data, pos: 100, end: data.length(), base: 0 }
  let result : Array[IndexEntry] = []
  let mut expected = 100
  for _ in 0..<count {
    let offset = words_to_bytes(r.be32(), r.pos - 4)
    let content_length = words_to_bytes(r.be32(), r.pos - 4)
    if offset != expected || content_length < 4 {
      raise InvalidData(r.pos - 8, "invalid or noncontiguous SHX entry")
    }
    if content_length > 2147483647 - 8 - offset {
      raise InvalidData(r.pos - 8, "SHX end offset overflows")
    }
    result.push({ offset, content_length })
    expected = offset + 8 + content_length
  }
  result
}

/// Fully verifies the SHX table against decoded SHP records.
pub fn validate_shx(shp : Bytes, shx : Bytes, limits? : ReadLimits = ReadLimits::default()) -> Unit raise ShapeError {
  let reader = IndexedReader::open(shp, shx, limits~)
  for i in 0..<reader.record_count() {
    ignore(reader.record_at(i))
  }
}

/// Random access validates file/index structure up front and geometry on access.
pub struct IndexedReader {
  data : Bytes
  file_header : Header
  entries : Array[IndexEntry]
  limits : ReadLimits
}

pub fn IndexedReader::open(shp : Bytes, shx : Bytes, limits? : ReadLimits = ReadLimits::default()) -> IndexedReader raise ShapeError {
  limits.validate()
  if shp.length() > limits.max_file_bytes {
    raise InvalidData(0, "file exceeds configured byte limit")
  }
  let file_header = read_header(shp)
  let index_header = read_header(shx)
  if file_header.kind != index_header.kind ||
    file_header.bounds != index_header.bounds ||
    file_header.zmin != index_header.zmin || file_header.zmax != index_header.zmax ||
    file_header.mmin != index_header.mmin || file_header.mmax != index_header.mmax {
    raise InvalidData(32, "SHP and SHX metadata disagree")
  }
  let entries = read_index(shx, limits~)
  let mut end = 100
  for i in 0..<entries.length() {
    let entry = entries[i]
    if entry.offset > shp.length() - 8 || entry.content_length > shp.length() - entry.offset - 8 {
      raise InvalidData(entry.offset, "index entry exceeds SHP bytes")
    }
    let r : ByteReader = { data: shp, pos: entry.offset, end: shp.length(), base: 0 }
    if r.be32() != i + 1 || words_to_bytes(r.be32(), entry.offset + 4) != entry.content_length {
      raise InvalidData(entry.offset, "index and record header disagree")
    }
    end = entry.offset + 8 + entry.content_length
  }
  if end != shp.length() {
    raise InvalidData(end, "index does not account for all SHP bytes")
  }
  { data: shp, file_header, entries, limits }
}

pub fn IndexedReader::record_count(self : IndexedReader) -> Int {
  self.entries.length()
}

pub fn IndexedReader::header(self : IndexedReader) -> Header {
  self.file_header
}

pub fn IndexedReader::entry(self : IndexedReader, index : Int) -> IndexEntry raise ShapeError {
  if index < 0 || index >= self.entries.length() {
    raise InvalidData(index, "record index outside table")
  }
  self.entries[index]
}

pub fn IndexedReader::record_at(self : IndexedReader, index : Int) -> Record raise ShapeError {
  let entry = self.entry(index)
  let start = entry.offset + 8
  let shape = decode_shape(self.data[start:start + entry.content_length].to_owned(), start, self.limits)
  if shape.kind != Null && shape.kind != self.file_header.kind {
    raise InvalidData(start, "record type differs from file header")
  }
  match shape.bounds() {
    Some(b) => if b.xmin < self.file_header.bounds.xmin || b.ymin < self.file_header.bounds.ymin ||
      b.xmax > self.file_header.bounds.xmax || b.ymax > self.file_header.bounds.ymax {
      raise InvalidData(start, "record exceeds file bounds")
    }
    None => ()
  }
  if shape.kind.has_z() {
    for p in shape.points {
      match p.z {
        Some(z) => if z < self.file_header.zmin || z > self.file_header.zmax { raise InvalidData(start, "Z outside file bounds") }
        None => ()
      }
    }
  }
  { number: index + 1, offset: entry.offset, content_length: entry.content_length, shape }
}

/// Only selected records are decoded; order and duplicate indices are preserved.
pub fn IndexedReader::select(self : IndexedReader, indices : Array[Int]) -> Array[Record] raise ShapeError {
  let result : Array[Record] = []
  for i in indices { result.push(self.record_at(i)) }
  result
}

/// Rebuild a missing index from a validated SHP stream.
pub fn rebuild_index(shp : Bytes, limits? : ReadLimits = ReadLimits::default()) -> Bytes raise ShapeError {
  let reader = ShpReader::open(shp, limits~)
  let entries = ByteWriter::new()
  while true {
    match reader.next() {
      None => break
      Some(record) => {
        entries.be32(record.offset / 2)
        entries.be32(record.content_length / 2)
      }
    }
  }
  let data = entries.bytes()
  let h = reader.header()
  let w = ByteWriter::new()
  w.append(write_header(100 + data.length(), h.kind, Some(h.bounds), Some((h.zmin, h.zmax)), Some((h.mmin, h.mmax))))
  w.append(data)
  w.bytes()
}

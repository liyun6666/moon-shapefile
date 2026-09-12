///|
pub(all) enum FieldType {
  Character
  Numeric
  Float
  Date
  Logical
} derive(Eq, Debug)

///|
pub(all) struct Field {
  name : String
  kind : FieldType
  width : Int
  decimals : Int
} derive(Eq, Debug)

///|
pub(all) enum Value {
  Text(String)
  Number(String)
  DateValue(String)
  LogicalValue(Bool)
  Missing
} derive(Eq, Debug)

///|
pub(all) struct Row {
  deleted : Bool
  values : Array[Value]
} derive(Eq, Debug)

///|
pub(all) struct Table {
  fields : Array[Field]
  rows : Array[Row]
} derive(Eq, Debug)

///|
pub(all) enum Encoding {
  Utf8
  Latin1
} derive(Eq, Debug)

///|
pub suberror DbfError {
  Invalid(Int, String)
} derive(Debug)

///|
pub struct Reader {
  data : Bytes
  schema : Array[Field]
  count : Int
  header : Int
  width : Int
  encoding : Encoding
}

///|
fn decode(data : Bytes, enc : Encoding, offset : Int) -> String raise DbfError {
  match enc {
    Utf8 =>
      @utf8.decode(data[:], ignore_bom=true) catch {
        _ => raise Invalid(offset, "invalid UTF-8")
      }
    Latin1 =>
      String::from_iter(data.iter().map(fn(b) { b.to_int().unsafe_to_char() }))
  }
}

///|
fn encode(text : String, enc : Encoding, offset : Int) -> Bytes raise DbfError {
  match enc {
    Utf8 => @utf8.encode(text[:])
    Latin1 => {
      let bytes : Array[Byte] = []
      for c in text.iter() {
        if c.to_int() > 255 {
          raise Invalid(offset, "character cannot be represented in Latin1")
        }
        bytes.push(c.to_int().to_byte())
      }
      Bytes::from_array(bytes)
    }
  }
}

///|
fn u16(data : Bytes, p : Int) -> Int {
  data[p].to_int() | (data[p + 1].to_int() << 8)
}

///|
fn validate_fields(fields : Array[Field]) -> Int raise DbfError {
  if fields.length() > 2046 {
    raise Invalid(8, "too many fields")
  }
  let mut width = 1
  let names : Map[String, Bool] = Map([])
  for i, f in fields {
    let p = 32 + i * 32
    let b = @utf8.encode(f.name[:])
    if b.length() == 0 || b.length() > 10 {
      raise Invalid(p, "field name must be 1 to 10 ASCII bytes")
    }
    for c in b {
      if c.to_int() < 33 || c.to_int() > 126 {
        raise Invalid(p, "invalid field name")
      }
    }
    if names.contains(f.name) {
      raise Invalid(p, "duplicate field name")
    }
    names[f.name] = true
    if f.width <= 0 || f.width > 255 {
      raise Invalid(p + 16, "invalid field width")
    }
    if f.decimals < 0 || f.decimals > 254 {
      raise Invalid(p + 17, "invalid decimal count")
    }
    match f.kind {
      Character =>
        if f.decimals != 0 {
          raise Invalid(p + 17, "character decimals must be zero")
        }
      Date =>
        if f.width != 8 || f.decimals != 0 {
          raise Invalid(p + 16, "date must have width 8 and no decimals")
        }
      Logical =>
        if f.width != 1 || f.decimals != 0 {
          raise Invalid(p + 16, "logical must have width 1 and no decimals")
        }
      Numeric | Float =>
        if f.decimals > 0 && f.decimals + 2 > f.width {
          raise Invalid(p + 17, "decimals exceed numeric width")
        }
    }
    width += f.width
    if width > 65535 {
      raise Invalid(10, "record exceeds DBF length limit")
    }
  }
  width
}

///|
pub fn open_reader(
  data : Bytes,
  encoding? : Encoding = Utf8,
  limits? : Limits = default_limits(),
) -> Reader raise DbfError {
  check_limits(limits)
  if data.length() > limits.max_bytes {
    raise Invalid(0, "DBF exceeds byte limit")
  }
  if data.length() < 33 {
    raise Invalid(0, "truncated DBF header")
  }
  if data[0] != b'\x03' {
    raise Invalid(0, "only dBASE III without memo is supported")
  }
  let header = u16(data, 8)
  let width = u16(data, 10)
  if header < 33 || (header - 33) % 32 != 0 || header > data.length() {
    raise Invalid(8, "invalid header length")
  }
  if width < 1 {
    raise Invalid(10, "invalid record length")
  }
  if data[header - 1] != b'\x0d' {
    raise Invalid(header - 1, "missing field terminator")
  }
  if data[7].to_int() >= 128 {
    raise Invalid(4, "record count exceeds supported range")
  }
  let count = data[4].to_int() |
    (data[5].to_int() << 8) |
    (data[6].to_int() << 16) |
    (data[7].to_int() << 24)
  if count > (data.length() - header) / width {
    raise Invalid(4, "record count exceeds available data")
  }
  let end = header + count * width
  if data.length() != end && (data.length() != end + 1 || data[end] != b'\x1a') {
    raise Invalid(end, "unexpected trailing bytes or invalid EOF marker")
  }
  if count > limits.max_records || (header - 33) / 32 > limits.max_fields {
    raise Invalid(4, "DBF exceeds record or field limit")
  }
  let fields : Array[Field] = []
  for p = 32; p < header - 1; p = p + 32 {
    let mut n = 0
    while n < 11 && data[p + n] != b'\x00' {
      n += 1
    }
    if n == 11 {
      raise Invalid(p, "unterminated field name")
    }
    let name = decode(data[p:p + n].to_owned(), Utf8, p)
    let kind = match data[p + 11] {
      b'C' => Character
      b'N' => Numeric
      b'F' => Float
      b'D' => Date
      b'L' => Logical
      _ =>
        raise Invalid(p + 11, "unsupported field type (memo is not supported)")
    }
    fields.push({
      name,
      kind,
      width: data[p + 16].to_int(),
      decimals: data[p + 17].to_int(),
    })
  }
  if validate_fields(fields) != width {
    raise Invalid(10, "record width differs from field widths")
  }
  { data, schema: fields, count, header, width, encoding }
}

///|
fn strip(data : Bytes) -> Bytes {
  let mut start = 0
  let mut end = data.length()
  while start < end && data[start] == b' ' {
    start += 1
  }
  while end > start && data[end - 1] == b' ' {
    end -= 1
  }
  data[start:end].to_owned()
}

///|
fn valid_number(s : String, f : Field, p : Int) -> Unit raise DbfError {
  let b = @utf8.encode(s[:])
  let mut i = 0
  if b.length() > 0 && (b[0] == b'-' || b[0] == b'+') {
    i += 1
  }
  let mut digits = 0
  let mut fraction = 0
  let mut dot = false
  while i < b.length() {
    let c = b[i]
    if c >= b'0' && c <= b'9' {
      digits += 1
      if dot {
        fraction += 1
      }
    } else if c == b'.' && !dot {
      dot = true
    } else {
      raise Invalid(p, "numeric value requires exact fixed decimal text")
    }
    i += 1
  }
  if digits == 0 || (dot && fraction == 0) || fraction > f.decimals {
    raise Invalid(p, "invalid numeric precision")
  }
  if b.length() > f.width {
    raise Invalid(p, "numeric value exceeds width")
  }
}

///|
fn valid_date(s : String, p : Int) -> Unit raise DbfError {
  let b = @utf8.encode(s[:])
  if b.length() != 8 {
    raise Invalid(p, "date must be YYYYMMDD")
  }
  for c in b {
    if c < b'0' || c > b'9' {
      raise Invalid(p, "date must contain digits")
    }
  }
  let y = (b[0].to_int() - 48) * 1000 +
    (b[1].to_int() - 48) * 100 +
    (b[2].to_int() - 48) * 10 +
    b[3].to_int() -
    48
  let m = (b[4].to_int() - 48) * 10 + b[5].to_int() - 48
  let d = (b[6].to_int() - 48) * 10 + b[7].to_int() - 48
  if y == 0 || m < 1 || m > 12 {
    raise Invalid(p, "invalid calendar date")
  }
  let days = match m {
    2 => if y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  if d < 1 || d > days {
    raise Invalid(p, "invalid calendar day")
  }
}

///|
pub fn Reader::record_count(self : Reader) -> Int {
  self.count
}

///|
pub fn Reader::fields(self : Reader) -> Array[Field] {
  self.schema.copy()
}

///|
pub fn Reader::row_at(self : Reader, index : Int) -> Row raise DbfError {
  if index < 0 || index >= self.count {
    raise Invalid(index, "record index out of range")
  }
  let start = self.header + index * self.width
  let deleted = match self.data[start] {
    b' ' => false
    b'*' => true
    _ => raise Invalid(start, "invalid deletion flag")
  }
  let values : Array[Value] = []
  let mut p = start + 1
  for f in self.schema {
    let raw = self.data[p:p + f.width].to_owned()
    let value = match f.kind {
      Character => {
        let mut end = raw.length()
        while end > 0 && (raw[end - 1] == b' ' || raw[end - 1] == b'\x00') {
          end -= 1
        }
        Text(decode(raw[0:end].to_owned(), self.encoding, p))
      }
      Numeric | Float => {
        let s = decode(strip(raw), Utf8, p)
        if s == "" {
          Missing
        } else {
          valid_number(s, f, p)
          Number(s)
        }
      }
      Date => {
        let s = decode(strip(raw), Utf8, p)
        if s == "" || s == "00000000" {
          Missing
        } else {
          valid_date(s, p)
          DateValue(s)
        }
      }
      Logical =>
        match raw[0] {
          b'T' | b't' | b'Y' | b'y' => LogicalValue(true)
          b'F' | b'f' | b'N' | b'n' => LogicalValue(false)
          b' ' | b'?' => Missing
          _ => raise Invalid(p, "invalid logical value")
        }
    }
    values.push(value)
    p += f.width
  }
  { deleted, values }
}

///|
pub fn read(
  data : Bytes,
  encoding? : Encoding = Utf8,
  limits? : Limits = default_limits(),
) -> Table raise DbfError {
  let reader = open_reader(data, encoding~, limits~)
  if reader.schema.length() > 0 &&
    reader.count > limits.max_cells / reader.schema.length() {
    raise Invalid(4, "DBF exceeds decoded cell limit; use row_at")
  }
  let rows : Array[Row] = []
  for i = 0; i < reader.count; i = i + 1 {
    rows.push(reader.row_at(i))
  }
  { fields: reader.fields(), rows }
}

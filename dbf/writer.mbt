///|
fn value_bytes(
  value : Value,
  field : Field,
  encoding : Encoding,
  offset : Int,
) -> Bytes raise DbfError {
  let data = match (field.kind, value) {
    (_, Missing) => b""
    (Character, Text(s)) => encode(s, encoding, offset)
    (Numeric, Number(s)) | (Float, Number(s)) => {
      valid_number(s, field, offset)
      @utf8.encode(s[:])
    }
    (Date, DateValue(s)) => {
      valid_date(s, offset)
      @utf8.encode(s[:])
    }
    (Logical, LogicalValue(v)) => if v { b"T" } else { b"F" }
    _ => raise Invalid(offset, "value type does not match field")
  }
  if data.length() > field.width {
    raise Invalid(offset, "encoded value exceeds field width")
  }
  data
}

///|
pub fn validate_table(table : Table) -> Unit raise DbfError {
  ignore(validate_fields(table.fields))
  for i, row in table.rows {
    if row.values.length() != table.fields.length() {
      raise Invalid(i, "row has wrong number of values")
    }
    for j, value in row.values {
      ignore(value_bytes(value, table.fields[j], Utf8, i))
    }
  }
}

///|
pub fn write(
  table : Table,
  encoding? : Encoding = Utf8,
  update_date? : UpdateDate = { year: 2000, month: 1, day: 1 },
  limits? : Limits = default_limits(),
) -> Bytes raise DbfError {
  check_limits(limits)
  check_update_date(update_date)
  let width = validate_fields(table.fields)
  let header = 33 + 32 * table.fields.length()
  if table.rows.length() > (2147483646 - header) / width {
    raise Invalid(4, "table exceeds supported byte length")
  }
  if table.rows.length() > limits.max_records ||
    table.fields.length() > limits.max_fields ||
    header + table.rows.length() * width + 1 > limits.max_bytes {
    raise Invalid(0, "output exceeds resource limits")
  }
  // Validate every value before allocating the output buffer.
  for i, row in table.rows {
    if row.values.length() != table.fields.length() {
      raise Invalid(i, "row has wrong number of values")
    }
    for j, value in row.values {
      ignore(value_bytes(value, table.fields[j], encoding, header + i * width))
    }
  }
  let data = Array::make(header + table.rows.length() * width + 1, b'\x00')
  data[0] = b'\x03'
  // Deterministic valid modification date: 2000-01-01.
  data[1] = (update_date.year - 1900).to_byte()
  data[2] = update_date.month.to_byte()
  data[3] = update_date.day.to_byte()
  for i = 0; i < 4; i = i + 1 {
    data[4 + i] = (table.rows.length() >> (i * 8)).to_byte()
  }
  data[8] = header.to_byte()
  data[9] = (header >> 8).to_byte()
  data[10] = width.to_byte()
  data[11] = (width >> 8).to_byte()
  for i, field in table.fields {
    let p = 32 + i * 32
    let name = @utf8.encode(field.name[:])
    for j, b in name {
      data[p + j] = b
    }
    data[p + 11] = match field.kind {
      Character => b'C'
      Numeric => b'N'
      Float => b'F'
      Date => b'D'
      Logical => b'L'
    }
    data[p + 16] = field.width.to_byte()
    data[p + 17] = field.decimals.to_byte()
  }
  data[header - 1] = b'\x0d'
  for i, row in table.rows {
    let mut p = header + i * width
    data[p] = if row.deleted { b'*' } else { b' ' }
    p += 1
    for j, value in row.values {
      let f = table.fields[j]
      let bytes = value_bytes(value, f, encoding, p)
      for k = 0; k < f.width; k = k + 1 {
        data[p + k] = b' '
      }
      let skip = match f.kind {
        Numeric | Float => f.width - bytes.length()
        _ => 0
      }
      for k, b in bytes {
        data[p + skip + k] = b
      }
      p += f.width
    }
  }
  data[data.length() - 1] = b'\x1a'
  Bytes::from_array(data)
}

///|
/// Exact, case-sensitive field lookup. Missing fields are explicit.
pub fn field_index(table : Table, name : String) -> Int? {
  for i, f in table.fields {
    if f.name == name {
      return Some(i)
    }
  }
  None
}

///|
/// Reorders or selects columns while retaining every physical row and deletion flag.
pub fn project(table : Table, names : Array[String]) -> Table raise DbfError {
  let fields : Array[Field] = []
  let indices : Array[Int] = []
  for name in names {
    match field_index(table, name) {
      Some(i) => {
        fields.push(table.fields[i])
        indices.push(i)
      }
      None => raise Invalid(0, "unknown projection field: " + name)
    }
  }
  ignore(validate_fields(fields))
  let rows : Array[Row] = []
  for i, row in table.rows {
    if row.values.length() != table.fields.length() {
      raise Invalid(i, "row has wrong number of values")
    }
    rows.push({
      deleted: row.deleted,
      values: indices.map(fn(j) { row.values[j] }),
    })
  }
  { fields, rows }
}

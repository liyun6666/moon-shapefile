///|
pub(all) struct Limits {
  max_bytes : Int
  max_records : Int
  max_fields : Int
  max_cells : Int
} derive(Eq, Debug)

///|
pub fn default_limits() -> Limits {
  {
    max_bytes: 268435456,
    max_records: 1000000,
    max_fields: 2046,
    max_cells: 10000000,
  }
}

///|
fn check_limits(limits : Limits) -> Unit raise DbfError {
  if limits.max_bytes < 33 ||
    limits.max_records < 0 ||
    limits.max_fields < 0 ||
    limits.max_cells < 0 {
    raise Invalid(0, "invalid resource limits")
  }
}

///|
pub(all) struct UpdateDate {
  year : Int
  month : Int
  day : Int
} derive(Eq, Debug)

///|
fn check_update_date(date : UpdateDate) -> Unit raise DbfError {
  if date.year < 1900 || date.year > 2155 || date.month < 1 || date.month > 12 {
    raise Invalid(1, "update date outside dBASE range")
  }
  let days = match date.month {
    2 =>
      if date.year % 4 == 0 && (date.year % 100 != 0 || date.year % 400 == 0) {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  if date.day < 1 || date.day > days {
    raise Invalid(3, "invalid update date day")
  }
}

///|
/// Checks values using the intended output encoding, including encoded byte widths.
pub fn validate_table_encoded(
  table : Table,
  encoding : Encoding,
) -> Unit raise DbfError {
  ignore(validate_fields(table.fields))
  for i, row in table.rows {
    if row.values.length() != table.fields.length() {
      raise Invalid(i, "row has wrong number of values")
    }
    for j, value in row.values {
      ignore(value_bytes(value, table.fields[j], encoding, i))
    }
  }
}

///|
/// Returns a bounded range of physical rows, including deleted records.
pub fn Reader::rows_range(
  self : Reader,
  start : Int,
  count : Int,
) -> Array[Row] raise DbfError {
  if start < 0 || count < 0 || start > self.count || count > self.count - start {
    raise Invalid(start, "record range out of bounds")
  }
  let rows : Array[Row] = []
  for i = start; i < start + count; i = i + 1 {
    rows.push(self.row_at(i))
  }
  rows
}

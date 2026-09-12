///|
fn one_field(
  kind : FieldType,
  width : Int,
  decimals : Int,
  value : Value,
) -> Table {
  {
    fields: [{ name: "VALUE", kind, width, decimals }],
    rows: [{ deleted: false, values: [value] }],
  }
}

///|
fn corrupted(data : Bytes, index : Int, value : Byte) -> Bytes {
  let a = data.to_array()
  a[index] = value
  Bytes::from_array(a)
}

///|
test "reader rejects all truncated prefixes" {
  let bytes = write(one_field(Character, 3, 0, Text("abc")))
  for n = 0; n < bytes.length() - 1; n = n + 1 {
    let failed = try {
      ignore(read(bytes[0:n].to_owned()))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  // EOF marker is optional in dBASE III.
  assert_eq(read(bytes[0:bytes.length() - 1].to_owned()).rows.length(), 1)
}

///|
test "header field terminator count widths and deletion corruption" {
  let bytes = write(one_field(Character, 3, 0, Text("abc")))
  for
    change in [
      (0, b'\x83'),
      (4, b'\xff'),
      (7, b'\xff'),
      (8, b'\x01'),
      (10, b'\x03'),
      (48, b'\x00'),
      (64, b'\x00'),
      (65, b'!'),
      (69, b'!'),
    ] {
    let failed = try {
      ignore(read(corrupted(bytes, change.0, change.1)))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "strict UTF8 and explicit Latin1" {
  let t = one_field(Character, 1, 0, Text("é"))
  let bytes = write(t, encoding=Latin1)
  assert_eq(read(bytes, encoding=Latin1), t)
  assert_true(
    try {
      ignore(read(bytes))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(write(t))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(write(one_field(Character, 10, 0, Text("中")), encoding=Latin1))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "exact numbers reject overflow exponents and excess precision" {
  for s in ["1e3", "NaN", "--1", "1.234", "1.", ".", "123456789", " 12", "1 2"] {
    assert_true(
      try {
        ignore(write(one_field(Numeric, 8, 2, Number(s))))
        false
      } catch {
        _ => true
      },
    )
  }
  for s in ["-0.00", "+1.20", "123", ".25"] {
    let t = one_field(Numeric, 8, 2, Number(s))
    assert_eq(read(write(t)), t)
  }
}

///|
test "calendar validation and missing values" {
  for
    s in [
      "20010229", "20000431", "00000101", "20261301", "20260001", "20260100", "2026011x",
    ] {
    assert_true(
      try {
        ignore(write(one_field(Date, 8, 0, DateValue(s))))
        false
      } catch {
        _ => true
      },
    )
  }
  for kind in [Numeric, Float, Date, Logical] {
    let width = if kind == Logical { 1 } else { 8 }
    let t = one_field(kind, width, 0, Missing)
    assert_eq(read(write(t)), t)
  }
}

///|
test "schema and row validation reject ambiguous or oversized structures" {
  let f : Field = { name: "DUP", kind: Character, width: 1, decimals: 0 }
  assert_true(
    try {
      validate_table({ fields: [f, f], rows: [] })
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      validate_table({ fields: [f], rows: [{ deleted: false, values: [] }] })
      false
    } catch {
      _ => true
    },
  )
  for width in [0, 256, -1] {
    assert_true(
      try {
        ignore(write(one_field(Character, width, 0, Text(""))))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      ignore(write(one_field(Numeric, 3, 2, Number(".2"))))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(write(one_field(Logical, 2, 0, LogicalValue(true))))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "random access and projection preserve physical rows" {
  let t : Table = {
    fields: [
      { name: "A", kind: Logical, width: 1, decimals: 0 },
      { name: "B", kind: Character, width: 3, decimals: 0 },
    ],
    rows: [
      { deleted: true, values: [LogicalValue(false), Text("a")] },
      { deleted: false, values: [Missing, Text("b")] },
    ],
  }
  let r = open_reader(write(t))
  assert_eq(r.record_count(), 2)
  assert_eq(r.row_at(1), t.rows[1])
  assert_true(
    try {
      ignore(r.row_at(-1))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(r.row_at(2))
      false
    } catch {
      _ => true
    },
  )
  let result = project(t, ["B"])
  assert_true(result.rows[0].deleted)
  assert_eq(result.rows[1].values, [Text("b")])
  assert_true(
    try {
      ignore(project(t, ["UNKNOWN"]))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "resource caps and update date are explicit" {
  let t = one_field(Character, 3, 0, Text("abc"))
  let b = write(t, update_date={ year: 2026, month: 9, day: 12 })
  assert_eq(b[1].to_int(), 126)
  assert_eq(b[2].to_int(), 9)
  assert_eq(b[3].to_int(), 12)
  let limits : Limits = {
    max_bytes: 1000,
    max_records: 0,
    max_fields: 10,
    max_cells: 100,
  }
  assert_true(
    try {
      ignore(read(b, limits~))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(write(t, limits~))
      false
    } catch {
      _ => true
    },
  )
  let cells : Limits = {
    max_bytes: 1000,
    max_records: 10,
    max_fields: 10,
    max_cells: 0,
  }
  assert_true(
    try {
      ignore(read(b, limits=cells))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(open_reader(b, limits=cells).row_at(0), t.rows[0])
  assert_true(
    try {
      ignore(write(t, update_date={ year: 2100, month: 2, day: 29 }))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(open_reader(b).rows_range(0, 1), t.rows)
  assert_eq(open_reader(b).rows_range(1, 0), [])
  assert_true(
    try {
      ignore(open_reader(b).rows_range(0, 2))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "encoded validation is distinct from default UTF8 validation" {
  let t = one_field(Character, 1, 0, Text("é"))
  validate_table_encoded(t, Latin1)
  assert_true(
    try {
      validate_table(t)
      false
    } catch {
      _ => true
    },
  )
}

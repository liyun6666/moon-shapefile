# DBF codec

Independent dBASE III (version 0x03, no memo) codec. Public Table, Row, Field and
Value types are directly constructible. `read` and `write` default to strict UTF-8;
pass `encoding=Latin1` explicitly for ISO-8859-1. No encoding is guessed from the
language-driver byte. Field names are unique, case-sensitive printable ASCII,
1–10 bytes. Character fields support widths 1–255 bytes.

Numeric/Float values use exact fixed decimal strings, including sign and trailing
fractional zeroes. No floating-point conversion, exponent notation, implicit
rounding, precision reduction, or width truncation occurs. Fractional digits must
fit the field decimals. Dates use real Gregorian YYYYMMDD dates, years 0001–9999.
Logical T/Y/F/N is accepted case-insensitively; space and ? mean Missing.

Character reads remove trailing space/NUL padding; blank character data becomes
Text(""). Writing Missing to a character column therefore reads back as Text("").
Blank numeric/date data means Missing; date 00000000 also reads as Missing.
These are format-level normalizations, not byte-for-byte preservation. Physical
row order and deleted flags are always retained. Reserved header bytes and field
addresses are not preserved. The optional EOF marker is accepted; other trailing
bytes, truncated records and unsupported field types are rejected.

`open_reader` validates the structure, then `row_at` decodes an individual physical
record lazily. `rows_range` reads a checked interval. Malformed values in other
records are detected only when those records are decoded. `read` validates all
records by materializing them. `fields()` returns a schema copy.

`Limits` caps input/output bytes, records, fields and materialized cells. Defaults:
256 MiB, one million records, 2046 fields, ten million cells. Callers can supply
larger explicit limits; signed integer overflow guards still apply. The cell cap
applies to full read, so row_at can process large tables without materializing all
values. `write` has deterministic update date 2000-01-01; pass `update_date` to
write an explicit Gregorian date in the dBASE header range 1900–2155.

`validate_table` uses UTF-8 byte widths; `validate_table_encoded` checks the chosen
encoding. `field_index` and `project` use exact case-sensitive names; projection
preserves row order and deletion flags, and rejects missing/duplicate columns.
`DbfError::Invalid(Int,String)` reports byte offsets for input failures; table
validation and out-of-range APIs use logical row/index positions where no input
byte exists.

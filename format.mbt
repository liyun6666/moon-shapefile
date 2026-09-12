///|
/// Human-readable summaries for command-line adapters.
pub fn shape_type_name(kind : ShapeType) -> String {
  match kind {
    Null => "Null"
    Point => "Point"
    PolyLine => "PolyLine"
    Polygon => "Polygon"
    MultiPoint => "MultiPoint"
    PointZ => "PointZ"
    PolyLineZ => "PolyLineZ"
    PolygonZ => "PolygonZ"
    MultiPointZ => "MultiPointZ"
    PointM => "PointM"
    PolyLineM => "PolyLineM"
    PolygonM => "PolygonM"
    MultiPointM => "MultiPointM"
  }
}

///|
pub fn bounds_to_text(bounds : Bounds?) -> String {
  match bounds {
    None => "empty"
    Some(b) =>
      "[" +
      b.xmin.to_string() +
      ", " +
      b.ymin.to_string() +
      "; " +
      b.xmax.to_string() +
      ", " +
      b.ymax.to_string() +
      "]"
  }
}

///|
pub fn stats_to_text(stats : ShapeStats) -> String {
  "records=" +
  stats.record_count.to_string() +
  " points=" +
  stats.point_count.to_string() +
  " parts=" +
  stats.part_count.to_string() +
  " null=" +
  stats.null_count.to_string() +
  " length=" +
  stats.total_length.to_string() +
  " area=" +
  stats.total_area.to_string() +
  " bounds=" +
  bounds_to_text(stats.bounds)
}

///|
pub fn validate_filename_prefix(prefix : String) -> Unit raise ShapeError {
  if prefix.is_empty() || prefix.length() > 8 {
    raise InvalidData(0, "Shapefile prefix must be 1 to 8 characters")
  }
  for ch in prefix.chars() {
    if !((ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_' ||
      ch == '-') {
      raise InvalidData(0, "Shapefile prefix contains an invalid character")
    }
  }
}

///|
test "format helpers provide stable diagnostics" {
  assert_eq(shape_type_name(PointZ), "PointZ")
  assert_eq(bounds_to_text(None), "empty")
  validate_filename_prefix("roads_01")
  assert_true(
    try {
      validate_filename_prefix("too-long-name")
      false
    } catch {
      _ => true
    },
  )
}

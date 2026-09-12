/// A geometry table whose rows retain the physical SHP/DBF record alignment.
pub(all) struct Dataset {
  kind : ShapeType
  shapes : Array[Shape]
  table : @dbf.Table
  prj : String?
} derive(Debug)

pub(all) struct DatasetFiles { shp : Bytes; shx : Bytes; dbf : Bytes; prj : String? } derive(Debug)

pub fn Dataset::validate(self : Dataset) -> Unit raise ShapeError {
  if self.shapes.length() != self.table.rows.length() { raise InvalidData(0, "geometry and DBF row counts differ") }
  for s in self.shapes { if s.kind != Null && s.kind != self.kind { raise InvalidData(0, "dataset shape type mismatch") }; s.validate() }
  try { ignore(@dbf.validate_table(self.table)) } catch { _ => raise InvalidData(0, "invalid DBF table") }
}

pub fn read_dataset(shp : Bytes, shx : Bytes, dbf : Bytes, encoding? : @dbf.Encoding = @dbf.Utf8, prj? : String? = None) -> Dataset raise ShapeError {
  let sf = read_shp(shp)
  validate_shx(shp, shx)
  let table = try { @dbf.read(dbf, encoding~) } catch { _ => raise InvalidData(0, "invalid DBF bytes") }
  let d : Dataset = { kind: sf.kind, shapes: sf.records.map(r => r.shape), table, prj }
  d.validate()
  d
}

pub fn write_dataset(self : Dataset, encoding? : @dbf.Encoding = @dbf.Utf8) -> DatasetFiles raise ShapeError {
  self.validate()
  let files = write_shp(self.kind, self.shapes)
  let dbf = try { @dbf.write(self.table, encoding~) } catch { _ => raise InvalidData(0, "DBF table cannot be encoded") }
  { shp: files.shp, shx: files.shx, dbf, prj: self.prj }
}

pub fn Dataset::select_indices(self : Dataset, indices : Array[Int]) -> Dataset raise ShapeError {
  let shapes : Array[Shape] = []
  let rows : Array[@dbf.Row] = []
  for i in indices {
    if i < 0 || i >= self.shapes.length() { raise InvalidData(i, "dataset index outside rows") }
    shapes.push(self.shapes[i]); rows.push(self.table.rows[i])
  }
  { kind: self.kind, shapes, table: { fields: self.table.fields, rows }, prj: self.prj }
}

pub fn Dataset::filter_bbox(self : Dataset, bounds : Bounds, include_deleted? : Bool = false) -> Dataset raise ShapeError {
  bounds.validate()
  let indices : Array[Int] = []
  for i in 0..<self.shapes.length() {
    if (include_deleted || !self.table.rows[i].deleted) && self.shapes[i].intersects_bounds(bounds) { indices.push(i) }
  }
  self.select_indices(indices)
}

pub fn Dataset::filter_equal(self : Dataset, field : String, value : @dbf.Value, include_deleted? : Bool = false) -> Dataset raise ShapeError {
  let index = @dbf.field_index(self.table, field)
  let indices : Array[Int] = []
  match index {
    None => raise InvalidData(0, "unknown DBF field")
    Some(j) => for i in 0..<self.shapes.length() {
      if (include_deleted || !self.table.rows[i].deleted) && self.table.rows[i].values[j] == value { indices.push(i) }
    }
  }
  self.select_indices(indices)
}

pub fn Dataset::project_fields(self : Dataset, names : Array[String]) -> Dataset raise ShapeError {
  let table = try { @dbf.project(self.table, names) } catch { _ => raise InvalidData(0, "unknown projected field") }
  { kind: self.kind, shapes: self.shapes, table, prj: self.prj }
}

pub fn Dataset::to_geojson(self : Dataset, allow_projected? : Bool = false, include_deleted? : Bool = false) -> Json raise ShapeError {
  self.validate()
  let features : Array[Json] = []
  for i in 0..<self.shapes.length() {
    if include_deleted || !self.table.rows[i].deleted {
      features.push(Json::object({ "type": Json::string("Feature"), "geometry": self.shapes[i].to_geojson(allow_projected~), "properties": Json::null() }))
    }
  }
  Json::object({ "type": Json::string("FeatureCollection"), "features": Json::array(features) })
}

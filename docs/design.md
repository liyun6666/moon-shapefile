# moonbit9 accepted design

Owner/applicant: 马昀昀, 1498657823@qq.com. Only destination repository:
https://github.com/liyun6666/moonbit9 (remote default branch main).

Core library: in-memory Bytes API with checked offsets, typed geometry and bounded
record decoding. SHP and SHX share header validation; SHX offsets are checked
against the actual SHP record boundaries. Null, Point, MultiPoint, PolyLine,
Polygon and Z/M variants are supported. Nonfinite coordinates are rejected.
DBF is an independent package with explicit encoding and exact numeric text.
Dataset joins geometry and attributes by physical record index, including deleted
records. Selection always preserves this alignment. CLI is a thin native adapter.

Geometry model: public ShapeType enum (Null, Point, PolyLine, Polygon, MultiPoint,
PointZ, PolyLineZ, PolygonZ, MultiPointZ, PointM, PolyLineM, PolygonM, MultiPointM).
Coordinate {x:Double,y:Double,z:Double?,m:Double?}; Shape {kind:ShapeType,
points:Array[Coordinate],parts:Array[Int]}. Bounds {xmin,ymin,xmax,ymax:Double}.
Record {number:Int,offset:Int,content_length:Int,shape:Shape}.
Shapefile {kind:ShapeType,records:Array[Record],bounds:Bounds?}.
API read_shp(Bytes)->Shapefile raise ShapeError;
write_shp(ShapeType,Array[Shape])->ShapeFiles raise ShapeError;
ShapeFiles {shp:Bytes,shx:Bytes}; validate_shx(Bytes,Bytes)->Unit raise ShapeError.

Explicit boundaries: no projection transformations, no MultiPatch, no DBF Memo,
no network/ZIP reads. PRJ is preserved, not interpreted. GeoJSON output assumes
the caller supplies longitude/latitude; projected inputs require explicit opt-in
to non-RFC7946 coordinate output. Z is retained; M remains in shapefile only.
Polygon rings are grouped by containment; invalid intersecting rings rejected.

Usable workflows: administrative polygons -> GeoJSON; facilities -> bbox and
attribute subset -> shapefile; survey geometry/attributes -> interoperable files.
Validation: independent binary literals; malformed lengths/counts/indexes;
PyShp-generated data read by MoonBit and MoonBit output read by PyShp; deterministic
random geometries; meaningful regression cases. CI check/build/test and interop.
Target >4000 effective MoonBit implementation lines excluding tests, blank lines,
comments and generated code. No filler. At least ten meaningful development commits.
Upstream: PyShp https://github.com/GeospatialPython/pyshp MIT; ESRI format reference.
Do not claim full PyShp parity. Preserve upstream notice in THIRD_PARTY.md.

Ruling: use this otherwise-empty clone on develop; no existing checkout to protect.
Ruling: GitHub push is user-authorized but credentials currently lack permission.
Ruling: continue independent local work while user resolves repository access.

# moon-shapefile

`moon-shapefile` 是使用 MoonBit 编写的 Shapefile 地理数据读写与转换库，提供
SHP 几何文件、SHX 索引文件和 DBF 属性表的联合处理能力。

## 项目能力

- 读取和写入 Null、Point、MultiPoint、PolyLine、Polygon 及 Z/M 变体；
- 检查文件头、记录长度、索引偏移、几何范围和属性行数量；
- 保留 DBF 物理行顺序和删除标记，避免几何与属性错位；
- 按边界框或属性字段筛选数据集；
- 将点、线和多边形转换为 GeoJSON，并检查多边形环拓扑；
- 提供统计、几何变换、最近顶点和格式化诊断接口；
- 对截断文件、错误索引、非法坐标、字段溢出和不支持类型返回结构化错误。

## 最小示例

```mbt
let shape = {
  kind: @shapefile.Point,
  points: [@shapefile.coordinate(116.4, 39.9)],
  parts: [],
}
let files = @shapefile.write_shp(@shapefile.Point, [shape])
let parsed = @shapefile.read_shp(files.shp)
println(parsed.records.length().to_string())
```

运行测试和检查：

```bash
moon check --deny-warn
moon test --deny-warn
moon fmt --check
moon build --target wasm-gc
moon run cmd/main
```

## 设计边界

首版不做坐标投影转换、MultiPatch、DBF Memo、网络或 ZIP 文件读取。`.prj`
文件可以随数据集保存，但不会被库自动解释。GeoJSON 导出默认要求调用者确认
坐标是经纬度；投影坐标需要显式设置 `allow_projected=true`。

## 许可证和来源

本项目采用 MIT 许可证。文件布局依据公开的 ESRI Shapefile Technical
Description，DBF 兼容性参考 PyShp 的公开行为，但仓库不包含 PyShp 源代码。
详细说明见 [THIRD_PARTY.md](THIRD_PARTY.md) 和 [项目申报书](docs/项目申报书.md)。

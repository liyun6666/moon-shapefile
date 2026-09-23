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

在使用方 MoonBit 项目中安装依赖：

```bash
moon add liyun6666/moon-shapefile@0.1.1
```

在使用方的 `moon.pkg` 中配置导入：

```moonbit
import {
  "liyun6666/moon-shapefile" @shapefile,
}
```

以下代码放在 `fn main raise { ... }` 中运行：

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

本仓库的完整示例位于 `cmd/main/main.mbt`，执行 `moon run cmd/main`：
构造带 `NAME=Beijing` 属性的点数据集，写入并读取 SHP/SHX/DBF 字节，
断言几何和属性一致，按属性筛选后输出带 `properties` 的 GeoJSON。
示例在内存中运行，无需下载外部样本或配置文件路径。

## 属性导出与编码

`Dataset::to_geojson` 按 DBF 字段名导出所有属性：字符和日期为字符串
（日期保留 `YYYYMMDD`），Numeric/Float 也使用字符串，以保留大整数、
小数尾零及符号；逻辑值为 JSON 布尔值，Missing 为 `null`。
默认跳过标记删除的物理行，`include_deleted=true` 可包含这些行。
导出仅支持数据集到 FeatureCollection；GeoJSON 导入接口接收几何对象。

DBF 默认按 UTF-8 检查字段字节宽度。处理 Latin1 文件时，
`read_dataset`、`write_dataset`、`Dataset::validate` 和 `Dataset::to_geojson`
均须传入 `encoding=@dbf.Latin1`（使用方需导入
`"liyun6666/moon-shapefile/dbf"`）。Dataset 不保存源编码；JSON 字符串
保留解码后的 Unicode 文本，导出参数只控制 DBF 字段宽度校验。
若改用 UTF-8 写出，需相应扩大字符字段宽度，不能静默截断。

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

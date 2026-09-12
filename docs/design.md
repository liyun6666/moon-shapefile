# moonbit9 设计说明

项目负责人：马昀昀。唯一提交仓库为
<https://github.com/liyun6666/moonbit9>，远程默认分支为 `main`。

## 定位与接口

本项目使用 MoonBit 原生 `Bytes` 接口处理 SHP、SHX 和 DBF 数据，不依赖其他
语言运行时。二进制读取器先检查边界、长度和资源限制，再创建类型化几何记录。
SHP 与 SHX 共用文件头校验，SHX 的偏移和记录长度必须与 SHP 实际记录边界一致。

主要接口包括 `read_shp`、`write_shp`、`read_index`、`validate_shx`、
`read_dataset`、`write_dataset`、`shape_from_geojson` 和
`Shape::to_geojson`。数据集通过物理记录编号连接几何和 DBF 行；删除标记会保留，
筛选也不会改变剩余行与几何的对应关系。

## 几何模型

支持 Null、Point、MultiPoint、PolyLine、Polygon 及其 Z/M 变体。坐标由 X、Y
以及可选的 Z、M 组成；所有坐标和范围都必须是有限数。多部件几何通过 `parts`
保存每个部件的起始点。多边形导出时会检查环的闭合、相交、包含关系和方向，
不合法拓扑会返回错误，而不是静默修正。

## 交付边界

首版明确不实现坐标投影转换、MultiPatch、DBF Memo、网络读取和 ZIP 读取。`.prj`
作为配套文本保存但不解释。GeoJSON 默认按 RFC 7946 的经纬度语义导出；调用者
必须显式确认投影坐标才能导出。

## 测试与工程要求

测试使用独立构造的二进制字节、损坏输入、往返一致性和跨语言兼容性用例，覆盖
记录长度、索引偏移、删除行、数值精度、字段编码、Z/M 范围和多边形拓扑。仓库
通过 GitHub Actions 执行 `moon check`、`moon test`、`moon fmt --check`、
WASM 构建及最小运行示例。项目采用 MIT 许可证；来源和参考范围见
`THIRD_PARTY.md`。

## 赛事交付记录

当前仓库保留连续的功能开发历史，累计 20 次以上有实际内容的提交。当前版本的
MoonBit 源文件共 4,021 行，其中包含测试；核心实现、测试和文档均按功能边界
组织，不使用空提交或重复代码凑数。正式验收前继续以实际功能、测试和文档为准。

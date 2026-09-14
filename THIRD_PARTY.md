# 第三方来源与许可证说明

## Shapefile 格式

SHP、SHX 文件的字节布局依据公开的《ESRI Shapefile Technical Description》。
本项目是独立的 MoonBit 实现，仓库没有复制 ESRI 软件、闭源代码或其实现文件。

## PyShp

项目在 API 设计和互操作测试中参考了 PyShp：

- 项目：<https://github.com/GeospatialPython/pyshp>
- 许可证：MIT
- 参考范围：SHP/SHX/DBF 的公开读写行为和数据交换结果

本仓库不包含 PyShp 源代码。测试字节和示例数据由本项目独立构造；如果未来加入
来自上游的 fixture 或代码，必须同时保留版权、许可证和来源记录。

## 本项目许可证

moon-shapefile 采用 MIT 许可证，完整文本见根目录 `LICENSE`。第三方资料只用于格式
兼容和行为核对，不改变本项目代码的版权归属。

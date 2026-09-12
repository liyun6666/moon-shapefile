# 复审前自查记录

- 仓库：<https://github.com/liyun6666/moonbit9>，默认分支：`main`。
- 申请人：马昀昀；仓库主要提交者与申请人一致。
- 工具链：MoonBit 0.10.9。
- 本地命令：`moon check --deny-warn`、`moon test --deny-warn`、
  `moon fmt --check`、`moon build --target wasm-gc` 均通过。
- 测试结果：47 个测试通过，失败 0 个；覆盖二进制边界、SHP/SHX、DBF、
  删除标记、数值精度、Z/M 坐标、GeoJSON 拓扑和数据集筛选。
- 运行示例：`moon run cmd/main` 可输出 `moonbit9: Shapefile IO`。
- 规模：MoonBit 源文件总计 4,021 行，包含 855 行测试；不把生成文件计入提交。
- 提交历史：20 次以上有实际内容的功能提交，没有使用空提交或重复提交。
- 许可证：根目录 MIT；PyShp 参考范围和 ESRI 格式说明见 `THIRD_PARTY.md`。
- Mooncakes：已发布 `liyun6666/moonbit9@0.1.0`。
- 重复项目：复查 Mooncakes 模块目录后，未发现直接重复的 SHP/SHX/DBF 读写项目；
  `geo-mbt` 属于几何算法库，功能边界不同。
- CI：GitHub Actions 使用官方 MoonBit 安装脚本，并执行检查、测试、格式、WASM
  构建和运行示例。
- 申报书：见 `docs/项目申报书.md`，提交问卷时应以本人最终核实内容为准。

仍需在正式提交前确认：项目是否曾以相同范围参加过往届赛事，以及当前发布版本
是否需要在新增代码后递增 Mooncakes 版本号。

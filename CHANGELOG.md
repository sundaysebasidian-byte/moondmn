# Changelog

所有值得注意的变更记录在此文件。格式参考 Keep a Changelog，版本号遵循 Semantic Versioning。

## [0.1.0] - 2026-10-31

首个可运行版本，覆盖 OMG DMN 1.5 的核心决策语义并通过官方 TCK 的主要套件。

### Added

- 浏览器 Playground（`playground/`、`web/`）：DMN XML 编辑器、按类型生成的输入表单、DRG 依赖图、
  命中规则高亮的决策表、lint 定位和 FEEL 求值；导出 `feel_eval`、`parse_dmn`、`evaluate`、`lint`。
- `scripts/build-web.sh`、`web/smoke.mjs`、GitHub Pages 部署工作流。
- FEEL 精确十进制（34 位有效数字、半偶舍入）与无损 JSON 桥接。
- 日期、时间、日期时间、时长与时区类型；命名时区的夏令时规则与跨时区比较。
- 词法分析器：多词名称跨行折叠、转义字符串、`@"..."` 时间字面量、源码行列坐标。
- Pratt 解析器：算术与布尔优先级、列表/上下文/区间、四组区间定界符、
  比较式区间（`(<10)`、`(=10)` 等）、过滤器、路径、调用、迭代器、用户函数、
  `instance of` 与通用类型名。
- 求值器：三值逻辑、null 相等规则、区间成员测试、过滤器、`for`/`some`/`every`、
  日期与时长算术、函数闭包调用、`$types` 类型注册表。
- 约 90 个 FEEL 内置函数，含命名参数、聚合、列表变换、字符串、正则、时间函数；
  新增 `list replace` 的完整参数与匹配函数语义。
- DMN 模型：itemDefinition、输入数据、决策、决策表全部命中策略与聚合、
  DRG 依赖、BKM、决策服务、盒式表达式与 lint。
- 官方 TCK 驱动：decision / bkm / decisionService，typed 输入输出与错误结果。
- CLI：`moondmn feel`、`eval`、`lint`、`tck`，统一 JSON 错误输出与退出码。
- 库 API：`feel_eval`、`parse_model`、`evaluate_decision`、`compile`、`evaluate_compiled`。
- CI：Ubuntu/macOS/Windows 检查、构建、测试、格式与接口漂移检查，独立 TCK 任务。
- 文档：README、设计说明、一致性报告、提案、NOTICE 与示例模型。

### Changed

- 点路径后可以接多词名称，如 `Applicant.Credit Score`；按 context 里已知的键做最长匹配。
- 按声明类型把 JSON 里的日期、时间、时长字符串转成 FEEL 时态值，根包、CLI 和 Playground 共用同一个实现。
- Decimal128 指数范围：34 位系数，scale [-6111, 6176]，渐进下溢；`1e+34` 这类字面量可用。
- 命名参数缺省时绑定 null（用户函数、BKM 和内置函数）。
- 夏令时按时刻计算，内置 IANA 2026e 的 39 个时区名，覆盖 1970–2100 年。
- lint：输入域有限且被证明完整覆盖时，不再报 `W_POSSIBLE_GAP`。
- 畸形 boxed conditional（缺 `if`/`then`/`else`）返回带位置的错误，不再触发运行时异常。
- NOTICE 补充 TCK 测试用例的 CC 许可和 IANA 数据说明。
- 测试：每个后端 224 个单元测试，TCK Level 2 116/116，Level 3 3170/3291（96.32%）。

### Known limitations

- TCK Level 3 剩余 121 个失败，其中 87 个是已知缺陷，逐例列在 `docs/conformance.md`。
- 时区只有 39 个名称，只覆盖 1970–2100 年。

- 未实现 DMN 1.5 `import` 与外部 Java 函数。
- `now()` / `today()` 需要调用方注入时钟，没有隐含的系统时钟。
- 正则标志（`s`、`x`、`m`）与部分替换语义未覆盖。
- `range()` 函数的高级参数与部分隐式转换规则尚未实现。

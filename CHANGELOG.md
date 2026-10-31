# Changelog

所有值得注意的变更记录在此文件。格式参考 Keep a Changelog，版本号遵循 Semantic Versioning。

## [0.1.0] - 2026-10-31

首个可运行版本，覆盖 OMG DMN 1.5 的核心决策语义并通过官方 TCK 的主要套件。

### Added

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

### Known limitations

- 未实现 DMN 1.5 `import` 与外部 Java 函数。
- `now()` / `today()` 需要可注入时钟，暂不支持。
- 正则标志（`s`、`x`、`m`）与部分替换语义未覆盖。
- `range()` 函数的高级参数与部分隐式转换规则尚未实现。

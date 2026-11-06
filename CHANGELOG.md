# Changelog

所有值得注意的变更记录在此文件。格式参考 Keep a Changelog，版本号遵循 Semantic Versioning。

## 0.2.0

- 支持 DMN 多文件 import、嵌套导入、别名 FEEL/typeRef、namespace href、导入 Decision/InputData/BKM/DecisionService/ItemDefinition，32 层上限及结构化错误。CLI native/js 按模型目录加载，拒绝路径逃逸和符号链接。
- `parse_model` 新增可选 resolver；Model 新增 imports；新增 `bind_input` namespace 输入绑定接口。FEEL AST 新增 External，穷举 Expr 的使用方需补充分支。
- 新增 `register_external` 和可选 host 参数，按 class/method signature 调用宿主回调，先执行 FEEL 参数适配；支持 literal、boxed Java 和 BKM。未绑定返回 E_EXTERNAL_UNBOUND，不执行 JVM、不模拟 JDK。
- L2 116/116；L3 从 3258/3291 提高至 3265/3291（99.21%）；7 个 import 用例全部通过，Java 18 个继续失败；CI 最低通过数升至 3265。
- 新增独立测试、多文件模型与宿主桥示例；Playground 暂不提供 import resolver。源码版本 0.2.0，本次未发布包。

## 0.1.3

- `i` 比较完整 Unicode 大小写映射，支持共享多字符结果的单字符变体，不作传递闭包或多字符展开。
- 支持 `q` 字面模式及字面替换串，与 `i` 可组合，忽略 `m/s/x`；测试锁定 `x` 在转义解析前删除类外全部 XML 空白的规范行为。

- 为 `matches` 实现 Unicode 17.0 F&O 大小写变体、递归 XPath 字符类相减和捕获反向引用，保留大小写扩展与集合运算的顺序；增加模式资源上限。
- 按 DMN 1.5 表 53 保留比较式区间运算符；`Range` 新增 `comparison` 字段，直接构造结构的调用方需补 `None`，比较值 JSON 保留该字段。
- 修正 `!=` 比较集合的区间关系为 null，支持 `range("(..2)")` 和 `range("[2..)")`；修正字符串 `"-"` 的一元运算符误判。
- `replace`、`split` 共用 XPath 匹配器，支持字符类相减、捕获组替换和 F&O 零长/非法替换错误；按指令与输入位置去重，嵌套量词在 16–1000 字符输入上正确终止。
- 新增十六组独立规范回归测试；四后端各 289/289 通过。L2 116/116，L3 3258/3291（99.00%），原七个已知缺陷全部通过，剩余 33 个失败。CI 最低通过数同步提高到 3258。
- 实测检查、CLI 16 项、Web 26 项及接口再生检查见 `evidence/0.1.3-validation/`。

## 0.1.2

- 修正 README 最小消费示例缺少的 `feel/types` 导入，示例可在新模块中原样运行；设计和时态文档的测试数字改为引用一致性报告；新增源码、安装包与 Pages 的版本对应说明。引擎代码与 0.1.1 相同。

## 0.1.1

- 补齐类型化 FEEL 函数的单元素列表包装和 date 到 UTC 午夜转换；布尔一元表达式仅在引用 `?` 时按谓词判定。

- 修正声明类型在 boxed 表达式、上下文变量、函数参数及决策服务输出上的适配；保留 Any 集合中的嵌套列表。
- 修正布尔一元测试、字符串字典序、嵌套列表 membership、过滤器字段作用域、非法区间循环和幂运算结合性。
- 修正区间关系的同端点分支、COLLECT 默认输出、服务参数声明次序及本模型绝对 URI 引用。
- 修正正则 split、XPath x 空白处理与 BasicLatin 字符块、substring 小数长度、number 分隔符、date 转 time 与秒级 offset 格式化。
- 固定 TCK 提交不变：L2 116/116；L3 从 3170/3291 提高到 3251/3291（98.78%），剩余 40 个失败；动态时钟的 4 个用例继续失败。
- 新增 31 个规范语义测试块，四个目标各 273/273 通过；CLI 和 Web 验证记录见一致性报告。

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

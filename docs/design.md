# MoonDMN 设计说明

本文描述 MoonDMN 的分层结构、关键算法、错误模型与性能取舍。实现以可测试与可移植为先：
全部代码为 MoonBit，无 JVM、无运行时反射，可编译到 native、wasm-gc 与 js。

## 架构

```
cmd/main            命令行：feel / eval / lint / tck
playground          浏览器入口：JSON 字符串进出，导出 feel_eval / parse_dmn / evaluate / lint
api.mbt             库门面：字符串进、JSON 出
tck                 官方 TCK 驱动器（XML 用例 → 模型 API → JSON 报告）
dmn/model           模型解析后的语义层：DRG、决策表、BKM、决策服务、lint
dmn/xml             受限的命名空间感知 XML 解析器（拒绝 DTD，限制深度）
feel/eval           表达式求值、三值逻辑、过滤器、迭代器、函数调用
feel/builtins       FEEL 内置函数与参数名称表（含命名参数）
feel/parser         Pratt 解析器（表达式、区间、一元测试、类型名）
feel/lexer          词法分析（多词名称、时间字面量、源码坐标）
feel/types          Decimal、日期/时间/时长/时区、Value、Range、比较与 JSON
```

依赖方向自上而下单向：`cmd → api → tck/model/eval → parser → lexer → types`，`playground → model/eval`（只依赖引擎包，不依赖文件 IO），
`eval → builtins → types`。`types` 不依赖任何上层包，便于单独复用。

## 关键算法

### 精确数值

`Decimal` 由任意精度整数系数与十进制 `scale` 组成，最多 34 位有效数字（DMN number）。
加减按较大 scale 对齐；乘法后归一化；除法与超范围结果以“半偶舍入”收敛，
与 IEEE 754 decimal128 的默认舍入一致；scale 范围 [-6111, 6176]，溢出在库里抛 `E_DECIMAL_RANGE`，FEEL 四则的非有限结果为 null。
`1.23e+4`、`-0`、`0.00` 等字面量保留语义。`sqrt`、`log`、`exp` 和非整数幂仍经过有限精度浮点，不是精确 Decimal128。

### 三值逻辑与相等

`true and null = null`、`false and null = false`，`or` 对偶；`not(null) = null`。
`=` 采用 FEEL 相等规则：两侧为 null 得 true，仅一侧为 null 得 false；
类型种类不同（如 `"foo" = 100`）得 null；同类则调用结构化 `equals`。
区间、列表与上下文按结构递归比较。

### 一元测试与区间

决策表输入项与 `in` 使用同一 `Test` 语法树：`-`、比较、区间、表达式、`not`、逗号分隔多值。
区间端点可为空，四组定界符 `( ] [ [` 任意组合；`(<10)` 等比较形式会构造
单侧无界区间；`(=10)`、`(!=10)` 则保留比较运算符和端点，不能归并为双端区间。
`Range.comparison` 为 `None` 时沿用端点/开闭比较，为 `Some(op)` 时还比较运算符；
这是 DMN 1.5 表 53 要求的区别。比较值的 JSON 另含 `comparison` 字段。`!=` 表示不连续集合，表 78 的区间关系对其返回 null；`=` 保留闭点的端点关系。`range()` 接受开端缺值的单侧无界区间，拒绝闭端缺值。
公开 `Range` 结构新增此字段，直接构造结构的调用方需补 `comparison: None`。测试结果可为 null，用于“不确定”而非误判为 false。

### XPath 正则子集（0.1.3）

`matches`、`replace` 和 `split` 使用同一套项目内 AST 解析和带捕获状态的指令匹配器，不依赖宿主 JS/JVM 正则。
依据 [XPath/XQuery Functions 3.1 §5.6](https://www.w3.org/TR/xpath-functions-31/#regex-syntax)：

- 支持字面量、点、首尾锚、串接、分支、捕获组和 `(?:...)`、`?/*/+/{m,n}`（含非贪婪语法）、`i/s/m/x/q`。
- 字符集合支持字面量、范围、否定和递归相减，如 `[a-z-[aeiou]]`。先扩展每个范围的直接大小写变体，再取补集或差集。
- `i` 按 F&O 定义直接比较 `lower-case(C1) = lower-case(C2)` 或 `upper-case(C1) = upper-case(C2)`，变体限单字符，比较完整大小写结果（包括多字符结果相等的字符对）；不作传递闭包。使用 Unicode 17.0.0 `UnicodeData.txt` 与 `SpecialCasing.txt` 的无条件映射，匹配时不把单字符展开成多字符、不作区域设置转换。原始数据、许可和离线生成脚本位于 `scripts/`，运行 `python3 scripts/generate-unicode-fold.py` 后 `moon fmt` 可再生表。属性和字符类别不会被 `i` 扩展。
- `\N` 引用已闭合的捕获组；分支未参与时按空串匹配，重复捕获保留最后一次，大小写不敏感时逐码点比较；多位编号按已打开的组数消费。前向、自引用、缺失组及类内数字转义返回 `E_REGEX`。
- `m` 的锚按 LF 处理且不创建尾 LF 后的空行；`s` 允许点跨 CR/LF。`x` 在解析前删除字符类外的全部 XML 空白（TAB、LF、CR、空格），反斜杠不能保护这些空白；字符类内的空白保留。[F&O 3.1 §5.6.2](https://www.w3.org/TR/xpath-functions-31/#flags) 的示例 `matches("hello world", "hello\ sworld", "x")` 为 true，因为删除空白后模式为 `hello\sworld`。`matches("hello world", "hello\ world", "x")` 则为 false，因为模式变成 `hello\world`，其中 `\w` 不匹配空格。

范围边界：这是 `matches` 的子集实现，不宣称完整 XPath 正则兼容。XML 名称转义、完整 Unicode 属性/块名称尚未支持；`\p{IsBasicLatin}`、`\d/\D/\w/\W` 仍委托已有底层字符类别实现，未知属性明确返回 `E_REGEX`。`q` 将模式的每个字符按字面量匹配，替换串中的 `$` 和 `\` 也按字面量处理；可与 `i` 组合，与 `m/s/x` 组合时后三者不起作用。`replace` 支持 F&O 的 `$0`、`$N`（多位组号按已存在捕获组回退）、`\$` 和 `\\` 替换语义，保留分支优先级、贪婪及非贪婪选择；`replace` 和非空分隔符的 `split` 拒绝能匹配空串的模式。FEEL 的空分隔符 `split` 保留逐字符拆分。FEEL 层按现有调用失败规则把 `E_REGEX` 转为 null。

限制：模式至多 4096 个 Unicode 码点，组/字符类嵌套至多 128 层，重复计数至多 10000，编译指令至多 100000 条；每个起始位置至多执行 10000000 条指令，超限确定返回 `E_REGEX`（FEEL 为 null）。无反向引用时按（指令位置、输入位置）去重，消除嵌套空量词的重复搜索；带反向引用时将捕获值及捕获起点纳入去重状态，可能组合式回溯，不承诺线性时间。

### 时区与时间

`Zone = Unzoned | Fixed(seconds) | Named(name)`。DateTime 的 instant 先由完整本地时刻查
内置的 IANA 2026e 转换表得到偏移，再换算为 UTC 纳秒；表只含 39 个时区名，覆盖 1970–2100 年，
名称和年份之外分别返回 `E_ZONE_UNSUPPORTED` 和 `E_ZONE_RANGE`，DST 的 gap 返回 `E_ZONE_GAP`，overlap 取较早时刻。运行时不读取本机 zoneinfo。无时区时间在比较与日期-时间
算术中按 UTC 处理；两个命名时区按各自偏移比较；带偏移与无偏移的 date-time 混比是错误。
`date - PT1H` 向上取整到前一日，符合规范对日期粒度的处理。

### 决策模型

1. 解析：`dmn/xml` 产出树；`model` 收集 itemDefinition、inputData、decision、BKM、
   decisionService 与各盒式表达式。
2. 依赖：按 informationRequirement / knowledgeRequirement 做后序求值，带环检测与
   单次求值缓存。
3. 决策表：输入项先编译为 `Test`，命中后按 `U/A/P/First/RuleOrder/OutputOrder/Collect`
   策略汇总；输出表达式可使用命中上下文（`item` 相关变量）与聚合函数。
4. 类型：itemDefinition 递归描述为结构化类型字符串（`context<a: number,...>`、
   `list<...>`），通过保留上下文键 `$types` 注入求值环境，供 `instance of` 使用。
5. BKM/服务：BKM 参数绑定到调用环境；决策服务注入输入与内部决策后返回输出集合。
6. lint：检查未定义引用、重复规则和可能的缺口。输入列的 `inputValues` 或 ItemDefinition 的 `allowedValues`
   能推出有限域时（最多 4096 个输入组合）穷举验证覆盖，可证明完整就不告警；开放域、无法解析的谓词或超过上限时
   仍报 `W_POSSIBLE_GAP`。lint 不证明规则之间不重叠。

### 命中规则

引擎只返回决策表的最终值。Playground 为了高亮命中的规则行，把每张表改写成一张 `RULE ORDER`
的合成决策表（沿用原输入列与输入项，输出为规则序号），追加到同一份模型里求值，因此依赖、
类型转换和输入值约束与真实求值一致。这一步只在 `playground/` 内完成，没有改动引擎。

### TCK 驱动

扫描目录内 `*-test-*.xml`，读取 `<modelName>` 指向的 DMN 文件，按 `resultNode/@type`
分派到 decision / bkm / decisionService。期望值支持 `xsd` 基本类型、list、context、
range 与 `errorResult`。每个用例独立捕获错误并记录状态码（通过、语义不匹配、
预期错误未出现等），最终输出逐例 JSON 与汇总计数。

## 错误模型

所有失败统一为 `@types.EngineError = Failure(code, line, column, message)`，
CLI 将其序列化为 JSON 并以退出码 1 结束。主要错误码：

| 代码 | 含义 |
| --- | --- |
| `E_LEX` / `E_PARSE` | 词法或语法错误（含源码行列） |
| `E_NAME` / `E_TYPE` / `E_ARITY` | 名称、类型、参数错误 |
| `E_RANGE` / `E_NUMBER` / `E_DECIMAL_SYNTAX` | 数值范围与字面量错误 |
| `E_TEMPORAL` / `E_TIME_INVALID` / `E_DATETIME_INVALID` | 时间语义错误 |
| `E_ZONE_UNSUPPORTED` | 无法解析时区偏移 |
| `E_DMN_*` | 模型、决策表、迭代器、服务等 DMN 语义错误 |
| `E_UNSUPPORTED_SYNTAX` / `E_LANGUAGE` | 明确不支持的语法或表达式语言 |
| `E_IMPORT_UNSUPPORTED` | DMN 1.5 导入尚未实现 |
| `E_TCK_*` | TCK 用例层面的不匹配或预期错误差异 |

## 测试与性能

- 单元测试覆盖 Decimal、词法、语法、求值、模型、XML、时区与 lint，在 native、wasm-gc、wasm、js 四个后端运行；另有 CLI 进程级检查和 Playground 冒烟测试。当前数量见 [一致性报告](conformance.md#测试规模)。
- TCK 作为端到端回归，当前结果见 [一致性报告](conformance.md)。
- 全部用例在单机 native 后端约 2 秒内完成；无全局可变状态，除求值缓存外若干分配均随表达式规模线性。
- 安全边界：XML 解析拒绝 DTD/外部实体并限制嵌套深度；词法限制表达式长度；递归求值限制深度。

## 取舍与后续

优先保证规范语义与可诊断性，因此选择显式语法树与结构化错误，而非生成代码。
后续计划：DMN 1.5 import、外部函数桥接、正则标志完整支持、
区间函数高级参数，以及更细的性能基准。

## 输入边界与健壮性

DMN/XML 层没有显式 abort/panic/unreachable。剩余 strip_prefix/strip_suffix unwrap 均在前缀/后缀判定后；XML 栈索引在非空检查后，relation 行宽、decision table 输入/输出列数、函数实参数量与 filter 索引均先检查再访问。conditional 原先的三个无条件 unwrap 已删除，并拒绝缺失或重复分支。负年份 weekday 的负数组下标与日历换算中间值溢出已修复，用 49 组日期往返验证。测试用固定 LCG 种子对四类自编模型做 1200 次截断/变异，trap 不能被 EngineError catch 吞掉，因此会直接导致测试失败。XML 解析仍由受限 NamespaceReader 负责，DTD/超限输入被拒绝；这不等于完整 DMN XSD 验证或对所有资源耗尽情况的保证。

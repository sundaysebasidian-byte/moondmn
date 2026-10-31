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
与 IEEE 754 decimal128 的默认舍入一致。`1.23e+4`、`-0`、`0.00` 等字面量保留语义。

### 三值逻辑与相等

`true and null = null`、`false and null = false`，`or` 对偶；`not(null) = null`。
`=` 采用 FEEL 相等规则：两侧为 null 得 true，仅一侧为 null 得 false；
类型种类不同（如 `"foo" = 100`）得 null；同类则调用结构化 `equals`。
区间、列表与上下文按结构递归比较。

### 一元测试与区间

决策表输入项与 `in` 使用同一 `Test` 语法树：`-`、比较、区间、表达式、`not`、逗号分隔多值。
区间端点可为空，四组定界符 `( ] [ [` 任意组合；`(<10)` 等比较形式会构造
单侧无界区间，`(=10)` 构造闭区间。测试结果可为 null，用于“不确定”而非误判为 false。

### 时区与时间

`Zone = Unzoned | Fixed(seconds) | Named(name)`。DateTime 的 instant 先由日期查
IANA 风格的夏令时规则得到偏移，再换算为 UTC 纳秒。无时区时间在比较与日期-时间
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

- 单元测试覆盖 Decimal、词法、语法、求值、模型、XML 与 lint，三后端均通过。
- TCK 作为端到端回归：L2 116/116，L3 3170/3291（96.32%）。
- 全部用例在单机 native 后端约 2 秒内完成；无全局可变状态，除求值缓存外若干分配均随表达式规模线性。
- 安全边界：XML 解析拒绝 DTD/外部实体并限制嵌套深度；词法限制表达式长度；递归求值限制深度。

## 取舍与后续

优先保证规范语义与可诊断性，因此选择显式语法树与结构化错误，而非生成代码。
后续计划：DMN 1.5 import、外部函数桥接、正则标志完整支持、
区间函数高级参数，以及更细的性能基准。


## R1 输入边界核验

DMN/XML 层没有显式 abort/panic/unreachable。剩余 strip_prefix/strip_suffix unwrap 均在前缀/后缀判定后；XML 栈索引在非空检查后，relation 行宽、decision table 输入/输出列数、函数实参数量与 filter 索引均先检查再访问。conditional 原先的三个无条件 unwrap 已删除，并拒绝缺失或重复分支。另定位并修复负年份 weekday 的负数组下标与日历换算中间值溢出，以 49 组日期往返及 Web 负年份反例验证。新增测试用固定 LCG 种子对四类自编模型做 1200 次截断/变异，trap 不能被 EngineError catch 吞掉，因此会直接导致测试失败。XML 解析仍由受限 NamespaceReader 负责，DTD/超限输入被拒绝；这不等于完整 DMN XSD 验证或对所有资源耗尽情况的保证。

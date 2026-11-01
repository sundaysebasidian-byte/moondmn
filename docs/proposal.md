# MoonDMN 提案
- 项目名称：MoonDMN；仓库：https://github.com/sundaysebasidian-byte/moondmn
- 在线演示：https://sundaysebasidian-byte.github.io/moondmn/
## 解决什么问题，给谁用
审批、定价、风控、保险核保的规则常散落在代码里：改一次要发一次版，也说不清哪条规则起了作用。DMN 是标准的决策建模语言，
但现有引擎几乎都跑在 JVM 上。MoonDMN 是 MoonBit 上的 DMN 1.5 / FEEL 实现，同一份模型可跑在 native、wasm-gc 和 js，
面向业务规则、风控、保险、审批系统的开发者。
## 核心功能
FEEL 求值，决策表全部命中策略，InputData / ItemDefinition / BKM / 决策服务 / DRG，lint，CLI，库 API，以及浏览器 Playground
（编辑模型、生成输入表单、依赖图、命中规则高亮）。
## 证据
官方 DMN TCK（固定提交 `1e349176`，无跳过）：Level 2 为 116/116，Level 3 为 3258/3291（99.00%）；native、wasm-gc、wasm、js 四个后端各 281 个单元测试通过。
Level 3 剩余 33 个失败：Java 外部函数 18、跨文件 import 7、时钟注入 4、其他边界 4；0.1.3 修复原有七个已知缺陷，逐例原因见 docs/conformance.md。
## 覆盖矩阵
| 范围 | 状态 |
| --- | --- |
| FEEL：Decimal128 四则、三值逻辑、多词路径、列表/上下文/区间、内置函数；决策表全部命中策略、InputData、ItemDefinition、BKM、决策服务、DRG | 部分支持；仍有已知缺陷 |
| 日期、时间、时长、时区 | 部分支持；时区只内置 IANA 2026e 的 39 个名称，覆盖 1970–2100 年 |
| lint：未定义引用、重复规则、缺口 | 部分支持；有限枚举域可证明覆盖，开放域仍提示 |
| `now()` / `today()`；正则 Unicode、开闭区间关系、部分隐式转换 | 需调用方注入时钟；其余部分支持 |
| DMN 1.5 `import`、外部 Java 函数 | 明确不支持 |
`import` 要做多文件解析和命名空间合并，计划后续补。Java 外部函数依赖 JVM，与 wasm-gc / js 的目标冲突，不会实现。引擎不读系统时钟，时间由调用方注入。
## 基础与本期工作
2026-10-31 新建仓库从零开发，此前没有代码基础；仓库全部提交均为本期工作。技术路线：命名空间感知 XML 解析 → 作用域感知的 FEEL 词法/语法 → Decimal128 精确数值求值 → DRG 依赖图求值，同一库编译到 native、wasm-gc、js。
## 测试与文档计划
四后端 `moon check --deny-warn`、`moon test`、`moon fmt --check`，接口 `.mbti` 漂移检查，CLI 与 Playground 冒烟测试，独立 TCK 任务；文档为 README、API、设计、一致性、性能和变更记录。
## 原创与参考
实现、测试、示例模型均为原创。参考：OMG DMN 1.5 规范；dmn-tck 测试用例（https://github.com/dmn-tck/tck，Apache-2.0，用例采用 CC 署名-相同方式共享），只在运行时下载，不入库；IANA tzdata 2026e（公有领域）生成时区子集。

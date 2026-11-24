# MoonDMN 申报书
- 项目名称：MoonDMN；仓库：https://github.com/sundaysebasidian-byte/moondmn
- 在线演示：https://sundaysebasidian-byte.github.io/moondmn/

## 解决什么问题，给谁用

审批、定价、风控、保险核保的规则常散落在代码里：改一次要发一次版，也说不清哪条规则起了作用。DMN 是标准的决策建模语言，但现有引擎几乎都跑在 JVM 上。MoonDMN 是 MoonBit 上的 DMN 1.5 / FEEL 实现，同一份模型可跑在 native、wasm-gc 和 js，面向业务规则、风控、保险、审批系统的开发者。

## 核心功能

FEEL 求值、决策表全部命中策略、InputData / ItemDefinition / BKM / 决策服务 / DRG、lint、CLI、库 API，以及浏览器 Playground（编辑模型、生成输入表单、依赖图、命中规则高亮）。

## 规范覆盖矩阵

目标标准：OMG DMN 1.5 与 FEEL，以官方 DMN TCK（固定提交 `1e349176`，无跳过）验证。当前版本 0.4.0：Level 2 为 116/116，Level 3 为 3271/3291（99.39%），与 0.2.2 的逐例结果相同；不注入时钟时 Level 3 为 3269/3291（取自 0.4.0 变更记录，未单独重跑）。状态为已支持或明确不支持。

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| FEEL 语法、类型、内置函数（约 90 个）、正则 | 已支持 | Decimal128 精确数值、三值逻辑、多词名称、区间、日期时间 |
| 决策表（11 种命中策略）、BKM、决策服务、DRG、ItemDefinition | 已支持 | 含多文件导入模型 |
| 时区 | 已支持，数据有限 | 内置 IANA 2026e 的 39 个名称、1970–2100 年，范围外返回明确错误码 |
| `now()` / `today()` | 已支持 | 引擎不读系统时钟，由调用方注入 |
| 多文件 `import` 与命名空间引用 | 已支持 | Playground 内存多文件导入；7 个 TCK 用例；见下“已完成交付” |
| 外部函数（Java） | JVM 调用不支持；已支持宿主函数桥 | 见下“Java 外部函数” |

## Java 外部函数：影响与取舍

18 个 TCK 用例（占 Level 3 的 0.55%）全部是 `external {java:{class, method signature}}`，调用 JDK 类库（`java.lang.Math`、`Integer.valueOf`、`String.format` 等）。只有使用这种写法的模型受影响，决策表、FEEL 表达式、BKM、决策服务不受影响。wasm-gc 与 js 没有 JVM，引擎也不模拟 JDK，所以不实现 JVM 调用，这 18 个用例继续计为失败。已交付宿主函数桥：宿主按 class 加 method signature 注册回调，模型即可在三个后端调用宿主函数；未注册时返回明确错误码，不静默返回 null。

## 已知失败（Level 3 剩余 20 个）

| 原因 | 用例数 | 处理 |
| --- | ---: | --- |
| Java 外部函数 | 18 | 不实现 JVM 调用，见上 |
| 小数秒相等 | 2 | `time_005`、`datetime_003_a` 期望相差 100 微秒的两个值相等；引擎保留小数秒，判为不等。规范的值语义（DMN 1.5 表 66 等）未给出截断依据，这是我们的解读，未获上游确认；[证据](evidence/0.2.2/fractional-seconds/README.md) |

本次审计确认的参数检查、驱动时钟及同名时区相减问题已修复；剩余失败按下表计数。

## 已完成交付

1. 多文件 import：解析 `import` 元素，由宿主回调（CLI 按相对路径，Playground 使用虚拟文件表）提供被导入模型；支持别名、嵌套 import、命名空间隔离，以及 `别名.名称` 形式的 FEEL 与类型引用。实测：Level 3 增加 7 个通过用例，当时达到 3265/3291；0.2.2 审计修复后为 3271/3291。
2. 宿主函数桥：库 API 注册外部函数回调，native、wasm-gc、js 行为一致；CLI 不暴露回调注册。
3. 0.2.1 已发布，包含 Playground 多文件输入与内存 resolver；0.2.2 已发布，包含审计修复。0.3.0 与 0.4.0 已发布（0.4.0 于 2026-11-23 上架 mooncakes）：补齐区间文本往返、命名参数与类型声明检查、Unicode 字符串与正则字符类、大范围十进制对数和指数、决策表与模型的缺失／错误依赖诊断、带版本的模型导入，并修正 Playground 表单中的小数、时间与深层依赖图布局。这两个版本没有新增 TCK 通过用例，只保证逐例结果不回退。

## 生态贡献

- 下游示例：[moondmn-pricing](https://github.com/sundaysebasidian-byte/moondmn-pricing)（[mooncakes](https://mooncakes.io/docs/sundaysebasidian-byte/moondmn-pricing)），通过 mooncakes 依赖已发布的 `moondmn@0.2.2`：一份 DMN 1.3 保险定价模型（决策表、BKM、日期运算、三层决策依赖），经 OMG DMN XSD 校验，附库、命令行、覆盖每个规则分支和错误输入的测试（预期值手工推导，未用其他 DMN 引擎交叉验证）与 CI。它由 MoonDMN 作者编写，是示例，不代表第三方采用。
- 目前没有第三方使用记录，也没有提交 TCK 结果或上游问题。
## 基础与本期工作

2026-10-31 新建仓库，此前没有代码基础；仓库全部提交均为本期工作。技术路线：命名空间感知 XML 解析 → 作用域感知的 FEEL 词法/语法 → Decimal128 精确数值求值 → DRG 依赖图求值，同一库编译到 native、wasm-gc、js。

## 测试与文档

四后端 `moon check --deny-warn`、`moon test`、`moon fmt --check`，接口 `.mbti` 漂移检查，CLI 与 Playground 冒烟测试，独立 TCK 任务；文档为 README、API、设计、一致性、性能和变更记录。0.4.0 的数字：native、wasm-gc、wasm、js 四个目标各 433 个单元测试通过；CLI 38 项、Playground 37 项通过；Decimal128 对照 120 个算术用例通过。这些数字由发布后另行在干净克隆上重跑得到，用 MoonBit 0.1.20261119。

## 原创与参考

实现、测试、示例模型均为原创。参考：OMG DMN 1.5 规范；dmn-tck 测试用例（https://github.com/dmn-tck/tck，Apache-2.0，用例采用 CC 署名-相同方式共享），只在运行时下载，不入库；IANA tzdata 2026e（公有领域）生成时区子集。

多文件和宿主桥 API、错误码、路径限制与可运行示例见 [接入文档](imports-and-host-functions.md)。Playground 已支持多文件 import。文件 import 需 native/js 是 CLI 的平台说明；wasm-gc 无文件系统，通过 resolver 回调传入文件，浏览器 JS 构建使用内存虚拟文件表，不计为功能缺陷。

详细元素及非目标矩阵见 [README 支持边界](../README.md#支持边界)：DMN 1.1/1.2 明确拒绝，1.3–1.5 接受，DMNDI 布局及 knowledgeSource/authorityRequirement 不参与求值。

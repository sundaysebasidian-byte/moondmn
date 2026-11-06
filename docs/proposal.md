# MoonDMN 申报书

- 项目名称：MoonDMN；仓库：https://github.com/sundaysebasidian-byte/moondmn
- 在线演示：https://sundaysebasidian-byte.github.io/moondmn/

## 解决什么问题，给谁用

审批、定价、风控、保险核保的规则常散落在代码里：改一次要发一次版，也说不清哪条规则起了作用。DMN 是标准的决策建模语言，但现有引擎几乎都跑在 JVM 上。MoonDMN 是 MoonBit 上的 DMN 1.5 / FEEL 实现，同一份模型可跑在 native、wasm-gc 和 js，面向业务规则、风控、保险、审批系统的开发者。

## 核心功能

FEEL 求值、决策表全部命中策略、InputData / ItemDefinition / BKM / 决策服务 / DRG、lint、CLI、库 API，以及浏览器 Playground（编辑模型、生成输入表单、依赖图、命中规则高亮）。

## 规范覆盖矩阵

目标标准：OMG DMN 1.5 与 FEEL，以官方 DMN TCK（固定提交 `1e349176`，无跳过）验证：Level 2 为 116/116，Level 3 为 3258/3291（99.00%）。状态只有三种：已支持、本期交付、明确不支持。

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| FEEL 语法、类型、内置函数（约 90 个）、正则 | 已支持 | Decimal128 精确数值、三值逻辑、多词名称、区间、日期时间 |
| 决策表（11 种命中策略）、BKM、决策服务、DRG、ItemDefinition | 已支持 | 单文件模型 |
| 时区 | 已支持，数据有限 | 内置 IANA 2026e 的 39 个名称、1970–2100 年，范围外返回明确错误码 |
| `now()` / `today()` | 已支持 | 引擎不读系统时钟，由调用方注入 |
| 多文件 `import` 与命名空间引用 | **本期交付** | 7 个 TCK 用例；见下“本期交付” |
| 外部函数（Java） | JVM 调用不支持；**本期交付宿主函数桥** | 见下“Java 外部函数” |

## Java 外部函数：影响与取舍

18 个 TCK 用例（占 Level 3 的 0.55%）全部是 `external {java:{class, method signature}}`，调用 JDK 类库（`java.lang.Math`、`Integer.valueOf`、`String.format` 等）。只有使用这种写法的模型受影响，决策表、FEEL 表达式、BKM、决策服务不受影响。wasm-gc 与 js 没有 JVM，引擎也不模拟 JDK，所以不实现 JVM 调用，这 18 个用例继续计为失败。本期改为交付宿主函数桥：宿主按 class 加 method signature 注册回调，模型即可在三个后端调用宿主函数；未注册时返回明确错误码，不静默返回 null。

## 已知失败（Level 3 剩余 33 个）

| 原因 | 用例数 | 处理 |
| --- | ---: | --- |
| Java 外部函数 | 18 | 不实现 JVM 调用，见上 |
| 跨文件 import | 7 | 本期交付 |
| TCK 驱动不提供时钟 | 4 | 库已支持注入，不改 |
| 小数秒相等 | 2 | 保留精度，与 TCK 期望存在差异，依据 DMN 1.5 §10.3.2.3 |
| 无日期的命名时区 time 相减 | 2 | DST 偏移无法唯一确定，显式拒绝 |

范围内行为不正确的已知缺陷：0 个。

## 本期交付

1. 多文件 import：解析 `import` 元素，由宿主回调（CLI 按相对路径）提供被导入模型；支持别名、嵌套 import、命名空间隔离，以及 `别名.名称` 形式的 FEEL 与类型引用。目标：Level 3 增加 7 个通过用例，达到 3265/3291。
2. 宿主函数桥：库 API 与 CLI 注册外部函数回调，三个后端一致。
3. 发布 0.2.0，同步一致性报告、README 和变更记录。

## 基础与本期工作

2026-10-31 新建仓库，此前没有代码基础；仓库全部提交均为本期工作。技术路线：命名空间感知 XML 解析 → 作用域感知的 FEEL 词法/语法 → Decimal128 精确数值求值 → DRG 依赖图求值，同一库编译到 native、wasm-gc、js。

## 测试与文档计划

四后端 `moon check --deny-warn`、`moon test`、`moon fmt --check`，接口 `.mbti` 漂移检查，CLI 与 Playground 冒烟测试，独立 TCK 任务；文档为 README、API、设计、一致性、性能和变更记录。

## 原创与参考

实现、测试、示例模型均为原创。参考：OMG DMN 1.5 规范；dmn-tck 测试用例（https://github.com/dmn-tck/tck，Apache-2.0，用例采用 CC 署名-相同方式共享），只在运行时下载，不入库；IANA tzdata 2026e（公有领域）生成时区子集。

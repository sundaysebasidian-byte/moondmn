# MoonDMN｜跨平台业务决策引擎

[源代码](https://github.com/sundaysebasidian-byte/moondmn) · [在线演示](https://sundaysebasidian-byte.github.io/moondmn/) · [Mooncakes 0.4.0](https://mooncakes.io/docs/sundaysebasidian-byte/moondmn@0.4.0)

审批、定价和资格判定的规则常写在应用代码里。规则一变就要改代码，审核时也难追溯是哪条规则起了作用。MoonDMN 用 MoonBit 实现 FEEL 表达式、决策表和依赖求值。同一份规则可以在服务端、本地程序和浏览器中运行；业务人员能在 Playground 里改输入、看结果和命中的规则。

## 本期交付与验收终点

本期交付的是**无 JVM 的业务决策执行器**，不是完整的 DMN 1.5 移植。格式与规则语义参考 [OMG DMN 1.5](https://www.omg.org/spec/DMN/1.5/)；读取支持范围内的 DMN 1.3–1.5 XML。本期以表内模型、JSON 输入和指定决策的输出为验收范围，不以 TCK 级别作为目标。接受这些 XML 命名空间不代表实现该版本所有功能；不声明任何正式符合性级别。

| 本期必须做到 | 验收办法 |
| --- | --- |
| FEEL 业务表达式与决策表按规则得出结果 | 审批模型在通过、人工复核、拒绝三种输入下给出对应结果；金额用十进制计算。用 Node 调用浏览器构建产物校验规则命中。 |
| 一次输入带动同一模型内的多步决策 | 用保费示例，验证最后报价与表格命中；用多文件示例验证跨命名空间的决策、类型、可复用函数和决策服务。 |
| 规则可以离开 JVM 运行 | 用同一份审批模型和同一组输入在 Native、Wasm GC、JavaScript 的 MoonBit 库中求值，比较结果；另验证 Native CLI 和 Playground 使用的 JS 导出入口。 |
| 明确处理缺失输入和不执行的模型构件 | 缺文件、未绑定 Java 和 PMML 均有具体诊断；不影响执行的布局元数据只忽略。用于审批的示例中，显式空收入只可转人工，不能通过。 |

完整复跑顺序见[复审验收](review-acceptance.md)，面向评审的输入和预期结果见[快速演示](review-demo.md)。

## 明确不承诺的范围

- **不调用 JVM、JDK 或任意 Java 方法。** 宿主回调是一项单独的库扩展：由调用方为指定的 class 和完整 method signature 显式绑定回调，函数实现和类型转换不由引擎按 Java 规则提供。它不替代 JVM，也不计入本期申报的兼容能力。CLI 不开放注册。详见[宿主函数接入](imports-and-host-functions.md)。
- **不执行 PMML 模型，也不做完整 XSD 校验。** DMNDI 是图形布局信息，不参与执行；Playground 展示的是从决策依赖生成的图，不是标准图形交换工具。
- **时间有边界。** `now()` 和 `today()` 需要注入时钟；内置时区数据覆盖 39 个名称、1970–2100 年。保留小数秒精度，两个上游相等用例与现有结果不一致。
- **多文件不等于自动联网。** 库由调用方提供本地文件或内存模型；Native／JS CLI 读取受限的相对文件路径，Playground 读取上传到内存的文件。Wasm GC 库仍可用宿主提供的模型，无需文件系统。

## 实现与验证依据

MoonBit 实现 XML 模型解析、FEEL 求值、精确十进制运算和决策依赖执行；浏览器界面只编辑模型、收集输入、显示结果。[首个可追溯提交](https://github.com/sundaysebasidian-byte/moondmn/commit/474793716ca613c59375c65ccfb38291645d7248)的作者时间为北京时间 11 月 1 日 03:00。随后由 MoonBit 实现了[命名空间导入](https://github.com/sundaysebasidian-byte/moondmn/commit/6bd72a6a41931500331b0113687192dcdaeab420)、[Playground 多文件输入](https://github.com/sundaysebasidian-byte/moondmn/commit/15002a023af53ecd3eaf920e1421d84645b17ae3)与[固定时钟和审计复测](https://github.com/sundaysebasidian-byte/moondmn/commit/877a32b3455819133ace8620ea60c2268138fa2e)。XML 读取和基础工具使用 NOTICE 中列出的库，Unicode 与时区数据引用其原始来源。[多文件接入](imports-and-host-functions.md)和[设计文档](design.md)记录了实现。

基于发布版 0.4.0 的复审候选在 Native 复跑固定的上游 TCK 提交 `1e349176e5ae689d924a2a2c7a8df25c220d8b07`。注入时钟：Level 2 为 116 / 116，Level 3 为 3271 / 3291，20 个失败中 18 个调用 JDK，2 个涉及小数秒相等；不注入时钟时，Level 3 为 3269 / 3291。两种模式不跳过用例、不修改期望值，逐例确认只在无时钟时多出两项时钟失败。这些数字只用来证明没有掩盖差异，不代表正式符合性。[逐例报告](conformance.md) · [小数秒复核](evidence/0.2.2/fractional-seconds/README.md)。

[moondmn-pricing](https://github.com/sundaysebasidian-byte/moondmn-pricing) 是作者自建的保险定价接入示例，不作为第三方采用证明。项目使用 Apache-2.0；第三方材料见 [NOTICE](../NOTICE)。

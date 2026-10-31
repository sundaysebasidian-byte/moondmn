# MoonDMN 提案

- 项目名称：MoonDMN
- 仓库地址：https://github.com/sundaysebasidian-byte/moondmn
- Gitlink 链接：TODO(用户填写)

## 简介
MoonDMN 使用 MoonBit 从零实现 OMG DMN 1.5 决策模型与 FEEL 表达式引擎，不依赖 JVM，
输出逐例一致的官方 TCK 结果，可作为 MoonBit 服务的规则与决策内核。

## 方向与场景
业务规则（审批、定价、风控、资格判定）；跨平台嵌入（native/wasm-gc/js）；可执行规范与教学示例。

## 核心功能
FEEL：精确十进制、日期/时间/时长与时区、列表/上下文/区间、三值逻辑、过滤器、迭代器、
用户函数、BKM 与约 90 个内置函数。
DMN：itemDefinition、输入数据、决策表全部命中策略与聚合、DRG 依赖、盒式表达式、lint；
CLI 提供 feel/eval/lint/tck。

## 覆盖矩阵摘要
- 已验证：L2 116/116；L3 2994/3291（算术、列表、上下文、区间、时间、决策表、BKM）。
- 未支持：外部 Java 函数、DMN 1.5 import、部分正则标志、now/today、区间函数高级参数与部分隐式转换。

## 原创性与参考
实现、测试与文档均为原创；语义参考 OMG DMN 1.5 规范与 dmn-tck 公开用例，未复制第三方实现代码。

## 测试与文档
自动检查：`moon fmt --check`、`moon check --deny-warn`、三后端 `moon test`；TCK 固定提交
1e349176e5ae689d924a2a2c7a8df25c220d8b07，详见 docs/conformance.md、docs/design.md、
README.md、CHANGELOG.md。

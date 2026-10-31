# MoonDMN 提案
- 项目名称：MoonDMN
- 仓库地址：https://github.com/sundaysebasidian-byte/moondmn
- 在线演示：https://sundaysebasidian-byte.github.io/moondmn/
- Gitlink 链接：TODO(用户填写)

## 解决什么问题，给谁用
审批、定价、风控、保险核保的规则常散落在代码里：改一次要发一次版，也说不清哪条规则起了作用。
DMN 是标准的决策建模语言，但现有引擎几乎都跑在 JVM 上。MoonDMN 是 MoonBit 上的 DMN 1.5 / FEEL 实现，
同一份模型可以跑在 native、wasm-gc 和 js。面向业务规则、风控、保险、审批系统的开发者，
以及想在浏览器或边缘端执行 DMN 模型的人。Playground 里能编辑模型、填输入、看依赖图，并看到决策表命中了哪一行。

## 证据
官方 DMN TCK（固定提交 `1e349176`，无跳过）：Level 2 为 116/116，Level 3 为 3162/3291（96.08%）。
三个后端各 198 个单元测试全部通过。原始逐例报告在 `evidence/`，失败分类见 docs/conformance.md。

## 覆盖矩阵
| 范围 | 状态 |
| --- | --- |
| FEEL：精确十进制、三值逻辑、日期/时间/时长/时区、列表/上下文/区间、约 90 个内置函数 | 已支持 |
| 决策表全部命中策略（U/A/P/F/R/O/C/C+/C</C>/C#）、InputData、ItemDefinition、BKM、决策服务、DRG、lint | 已支持 |
| `now()` / `today()` | 需调用方注入时钟 |
| 正则标志、`range()` 高级参数、部分隐式转换 | 部分支持 |
| DMN 1.5 `import`、外部 Java 函数 | 明确不支持 |

## 不支持什么，为什么
`import` 需要多文件解析和命名空间合并，计划后续补，单文件模型不受影响。Java 外部函数依赖 JVM，与 wasm-gc / js 的目标冲突，不会实现。
引擎不读取隐含的系统时钟，时间由调用方注入，结果可重现。
## 原创与参考
实现、测试、示例模型均为原创。语义参照 OMG DMN 1.5 规范；TCK 只在运行时下载，不入库。

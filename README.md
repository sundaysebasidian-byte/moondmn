# MoonDMN

MoonDMN is a DMN 1.5 decision engine and FEEL expression evaluator written from
scratch in MoonBit. It runs without a JVM, compiles to native, wasm-gc and
JavaScript, and is validated case by case against the official DMN Technology
Compatibility Kit.

MoonDMN 是用 MoonBit 从零实现的 OMG DMN 1.5 决策引擎与 FEEL 表达式求值器。
它不依赖 JVM，可编译到 native / wasm-gc / js，并用官方 DMN TCK 逐例验证。

- 仓库：https://github.com/sundaysebasidian-byte/moondmn
- 许可证：Apache-2.0，第三方组件见 [NOTICE](NOTICE)
- 一致性结果：[docs/conformance.md](docs/conformance.md)
- 设计说明：[docs/design.md](docs/design.md)

## 目标与使用场景

- **业务规则**：审批、定价、风控、资格判定等需要可审计、可版本化决策逻辑的场景。
- **跨平台嵌入**：同一套规则编译到服务端（native）、浏览器或插件（wasm-gc）、
  Node/前端（js）。
- **规范实现与教学**：精确十进制、三值逻辑、时区与区间语义都有可执行示例和测试。
- **回归验证**：以官方 TCK 作为端到端回归，任何语义改动都会反映为通过数变化。

## 环境要求

- MoonBit 工具链 0.1.20261028 或更新版本（`moon version --all` 查看）。
- 首次构建会从 mooncakes 拉取 `Milky2018/xml` 与 `moonbitlang/x`。

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon version
moon build
```

## 安装与接入

当前版本尚未发布到 mooncakes 注册表；可直接克隆仓库使用：

```bash
git clone https://github.com/sundaysebasidian-byte/moondmn.git
cd moondmn
moon build
moon run cmd/main -- feel 'sum([1, 2, 3]) * 2'
```

输出：

```text
12
```

发布后计划支持 `moon add sundaysebasidian-byte/moondmn@0.1.0`。在现有 MoonBit
项目中接入时，把本仓库放在同一 workspace，并在包内添加：

```text
import {
  "sundaysebasidian-byte/moondmn",
}
```

即可调用库门面 `@moondmn.feel_eval`、`@moondmn.parse_model` 等。完整示例见
[`examples/api-demo`](examples/api-demo)：

```moonbit
fn main {
  let result = @moondmn.feel_eval("sum([1, 2, 3]) * 2") catch {
    @types.Failure(_, _, _, message) => "error: " + message
  }
  println(result) // 12
}
```

```bash
moon run examples/api-demo
```

## 命令行

所有命令都返回 JSON 或纯文本结果；失败时输出 `{"error": "...", "message": "..."}`
（带行列信息）并以退出码 1 结束。

### `feel`：求值表达式

```bash
moon run cmd/main -- feel 'Applicant Age >= 18' --context examples/input.json
```

```text
true
```

```bash
moon run cmd/main -- feel 'list replace([1, 2, 3], 2, 4)'
```

```text
[1,4,3]
```

### `eval`：执行模型决策

```bash
moon run cmd/main -- eval examples/eligibility.dmn \
  --decision Eligible --input examples/input.json
```

```text
true
```

### `lint`：静态检查

```bash
moon run cmd/main -- lint examples/eligibility.dmn
```

```text
[]
```

### `tck`：运行官方用例

```bash
./scripts/fetch-tck.sh
moon run cmd/main -- tck .tck/TestCases/compliance-level-2 \
  --json evidence/tck-level-2.json
moon run cmd/main -- tck .tck/TestCases/compliance-level-3 \
  --json evidence/tck-level-3.json
```

不加 `--json` 时把完整报告打印到标准输出，例如：

```bash
moon run cmd/main -- tck .tck/TestCases/compliance-level-3/0068-feel-equality
```

## 覆盖矩阵

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| FEEL 精确十进制 | ✅ | 34 位有效数字、半偶舍入、指数字面量 |
| 三值逻辑与 null 相等 | ✅ | `and`/`or`/`not`、FEEL 相等规则 |
| 日期/时间/时长/时区 | ✅ | 命名时区夏令时、跨时区比较、日期算术 |
| 列表/上下文/区间 | ✅ | 四组区间定界符、比较式区间、属性访问 |
| 过滤器/路径/迭代器 | ✅ | `[i]`、`.field`、`for`、`some`、`every` |
| 用户函数与 BKM | ✅ | 闭包、命名参数、知识模型调用 |
| 决策表 | ✅ | U/A/P/First/RuleOrder/OutputOrder/Collect 全策略 |
| 决策服务与 DRG | ✅ | 依赖排序、输入注入、输出集合 |
| 类型系统 | ✅ | itemDefinition、`instance of`、结构化类型描述 |
| 内置函数 | ✅（约 90 个） | 数学、字符串、正则、列表、上下文、时间 |
| 外部 Java 函数 | ❌ | 需要 JVM，明确不实现 |
| DMN 1.5 `import` | ❌ | 多文件导入尚未实现 |
| `now()` / `today()` | ❌ | 需要可注入时钟 |
| 正则 `s`/`x`/`m` 标志 | ⚠️ 部分 | 基础匹配可用，标志与部分替换未覆盖 |

## 一致性结果

本地运行固定提交 `1e349176e5ae689d924a2a2c7a8df25c220d8b07` 的官方 TCK：

| 级别 | 用例数 | 通过 | 通过率 |
| --- | --- | --- | --- |
| Level 2 | 116 | 116 | 100.0% |
| Level 3 | 3291 | 2994 | 91.0% |

目标为 Level 2 ≥ 95%、Level 3 ≥ 80%。逐套件矩阵、失败分类与复现步骤见
[docs/conformance.md](docs/conformance.md)，原始逐例报告在
[`evidence/`](evidence)。

## 与类似实现的差异

- **相比 JVM 引擎（Camunda/Drools/KIE）**：MoonDMN 不依赖 JVM，体积小，可编译到
  wasm-gc 与 js；错误以结构化 JSON 返回，适合嵌入多语言服务。
- **相比脚本语言实现**：使用精确十进制而非浮点，避免金额与比较规则中的舍入偏差；
  三值逻辑、null 相等与区间语义按 DMN 规范实现。
- **相比只覆盖语法的项目**：本仓库附带 TCK 驱动与逐例报告，结论可复现、可审计。

## 开发与测试

```bash
moon fmt --check
moon check --deny-warn
moon test                 # native
moon test --target wasm-gc
moon test --target js
moon info                 # 重新生成 .mbti，提交后不应有漂移
```

CI 在 Ubuntu、macOS、Windows 上执行上述检查，并单独运行 TCK 任务，参见
[`.github/workflows/ci.yml`](.github/workflows/ci.yml)。

## 限制与路线图

- 外部 Java 函数与 DMN 1.5 导入不在当前范围。
- `now()`/`today()` 将支持注入时钟，便于确定性测试。
- 正则标志与 `range()` 高级参数计划补齐。
- 部分隐式转换与函数元数据（`0103-feel-is-function`）仍有差距。
- 计划增加性能基准与更多示例模型。

## 许可证

Apache License 2.0，见 [LICENSE](LICENSE)；上游项目与测试数据来源见 [NOTICE](NOTICE)。

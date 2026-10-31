# 嵌入 API

推荐入口为根包：`feel_eval`、`parse_model`、`evaluate_decision`、`compile`、
`evaluate_compiled`。JSON 桥接保留精确数值。底层类型见生成的 `.mbti`。
`compile` 的 names 参数应包含有空格或运算符字符的输入名称。
不要在并发求值之间修改传入的 AST、Model 或 Value 容器。

三个求值入口均接受 `clock? : (() -> @types.DateTime)?`。
例如 `clock=Some(fn() { fixed })`；回调可返回固定时间或由宿主读取真实时钟。
`today()` 使用回调返回时间的本地日期，不先转换为 UTC。
未提供时钟时 now/today 给出 `E_BUILTIN_UNSUPPORTED`，不会读取隐含系统时间。
CLI 示例：

```bash
moon run cmd/main -- feel 'today()' --now 2024-02-29T23:30:00-05:00
```

错误可匹配 `@types.Failure(code, line, column, message)`；代码是稳定的机器判定入口，
文案用于诊断。解析/模型错误抛出 EngineError；内置函数的无效类型/签名返回 FEEL null，
未知函数和未实现能力仍为显式错误。

根包与底层公开函数已补充用途、单位或错误约束注释。底层包仍暴露跨包实现所需的类型和操作，
不承诺所有底层接口均为稳定 API。根包 clock 和 JSON API 已在 native、wasm-gc、js 单元测试调用验证。

## 浏览器与 JavaScript

`playground` 包通过 `link.js.exports` 导出四个函数，参数和返回值都是 JSON 字符串；
失败返回 `{"ok":false,"error":{"code","message","line","column"}}`，不抛异常。
构建：`scripts/build-web.sh`，产物 `web/dist/moondmn.js` 是 ES module。

| 函数 | 请求 | 成功响应 |
| --- | --- | --- |
| `feel_eval` | `{expression, context?, now?}` | `{ok, value, type, text}` |
| `parse_dmn` | `{xml}` | `{ok, name, namespace, inputs, decisions, knowledge, itemDefinitions, edges}` |
| `evaluate` | `{xml, decision, input?, now?}` | `{ok, value, type, text, values, tables}` |
| `lint` | `{xml}` | `{ok, findings:[{code, decision, message, line, column}]}` |

- `context` 与 `input` 可以是对象，也可以是 JSON 文本；传文本可保留数字的全部位数。
- `now` 是 ISO 日期时间，对应上面的 clock；不传则 `now()`、`today()` 报错。
- `values` 是求值路径上每个决策的结果；`tables` 以决策名为键，给出命中策略和命中的规则下标（从 0 开始）。
  求值失败时 `tables` 仍随错误返回，例如 UNIQUE 多条命中时能看到是哪几条。
- JSON 里的日期、时间、时长是字符串。`evaluate` 会按 InputData 声明的类型把它们转成对应的 FEEL 值，
  根包、CLI 与 Playground 共用 `@model.json_inputs`，递归处理 ItemDefinition、collection 和 null；非法字符串返回错误。

```js
import * as dmn from "./moondmn.js";
const res = JSON.parse(dmn.feel_eval(JSON.stringify({ expression: "0.1 + 0.2" })));
// { ok: true, value: 0.3, type: "number", text: "0.3" }
```

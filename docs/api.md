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

本阶段审查删除了 model 的 expression/boxed/type_descriptor/type_registry 和 eval 的 binary
以及 table 等内部辅助函数的 pub。根包与底层公开函数已补充用途、单位或错误约束注释。底层包仍暴露跨包实现所需的类型和操作，
不承诺所有底层接口均为稳定 API。未新增 native FFI；根包 clock 和 JSON API 已在 native、
wasm-gc、js 单元测试调用验证。未验证宿主 JavaScript 导出封装或浏览器集成。

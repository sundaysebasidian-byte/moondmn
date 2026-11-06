# 多文件模型与宿主函数

## 导入

`parse_model(xml, resolver=Some((location, model_namespace) => xml_text))` 由宿主提供 XML；回调可以抛出 `EngineError`。引擎在三个后端使用相同的模型和求值代码，不读取文件系统。回调接收相对于入口模型的累计位置；例如 `sub/a.dmn` 再导入 `b.dmn` 时收到 `sub/b.dmn`。绝对 URI 交给宿主处理。无 locationURI 时收到当前相对目录和目标 namespace，由宿主按 namespace 定位。

文件系统加载属于平台能力：CLI 的 native / js 文件加载器用于 eval、lint、tck。locationURI 相对声明模型的目录；拒绝绝对路径、URI、反斜杠、所有 `..` 路径段，以及导入路径中的符号链接/Windows reparse point。原生文件系统路径检查与读取不是原子操作，调用方应保持模型目录在求值期间不变。wasm CLI 的文件系统接口不提供链接元数据，导入文件会明确拒绝；wasm-gc 库使用宿主 resolver 即可加载相同模型。Playground 已支持多文件 import：可批量上传/拖入，或添加文件后填写文件名并粘贴内容，Entry 选择入口；浏览器的 JS 构建通过内存 resolver 加载虚拟文件，不依赖文件系统。

Playground 的解析、lint、求值接口均接受 `{xml, entry?, files?}`：`xml` 是入口内容，`entry` 默认 `main.dmn`，`files` 是文件名到 XML 内容的对象。locationURI 相对声明文件解析，路径区分大小写，规范化 `.`、重复分隔符与目录内的 `..`；拒绝逃出入口目录、绝对路径、URL、反斜杠和编码路径。文件名规范化后不得重复。省略 locationURI 时按 namespace 在当前虚拟目录匹配唯一 DMN 文件。包含 import 的模型通过 Input JSON 编辑输入，例如 `{"Shared":{"Amount":20}}`；别名、命名空间隔离和循环检测均由引擎处理。

```sh
moon run cmd/main --target native -- eval examples/imports/main.dmn \
  --decision Total --input examples/imports/input.json
# 56
moon run cmd/main --target native -- lint examples/imports/main.dmn
# []
```

每个模型保留独立的 Decision、InputData、BKM、DecisionService、ItemDefinition 索引；别名限定的 FEEL 名称和 typeRef 在对应作用域解析。requiredInput、requiredDecision、requiredKnowledge 通过 `namespace#id` 定位，未声明 namespace 的引用报错；不支持 `locationURI#id`。无别名导入只暴露该模块直接定义的元素，不传递暴露其嵌套空别名导入的元素；嵌套元素仍可在声明它们的直接导入作用域内使用，不占用外层默认命名空间。求值、typeRef 和 `instance of` 使用相同的可见性规则；同名元素保留本地声明或按 import 定义顺序最先导入的元素，丢弃后续同名元素，其余名字继续导入；非空别名与本地名称冲突仍报 `E_IMPORT_ALIAS`。输入可以按别名嵌套，例如 `{"Shared":{"Amount":20}}`；同一 namespace 的 InputData 在多处导入间共享。类型化 JSON 边界也能解析导入的 ItemDefinition。

宿主需要按 namespace 绑定输入时，使用 `dmn/model.bind_input(inputs, name, value, model_namespace="...")`；TCK 驱动使用该接口读取 inputNode 的 namespace 属性。runner 的比较、容差、错误白名单保持不变。

导入最多 32 层，以当前加载栈的 namespace 检测循环。错误携带 import 元素行列；循环错误保留闭合边的文件位置（入口模型在宿主 resolver API 中记为 `<root>`）：`E_IMPORT_NOT_FOUND`、`E_IMPORT_NAMESPACE`、`E_IMPORT_ALIAS`、`E_IMPORT_TYPE`、`E_IMPORT_CYCLE`、`E_IMPORT_DEPTH`、`E_IMPORT_PATH`；引用错误为 `E_REFERENCE`。

## 宿主函数桥

宿主按 class 与完整 method signature 注册回调；这两个字符串构成精确的二元键，不解析 Java 重载、不执行 JVM，也不模拟 JDK。注册表属于调用方的 `host`，没有进程全局状态。回调接收按 FEEL 参数类型适配后的 `Array[Value]`，返回 `Value`，可抛出 `EngineError`。Java 基本类型、装箱、varargs 与业务语义由宿主自行定义。

```moonbit
let host = Map([])
@moondmn.register_external(host, "Example", "echo(number)", args => args[0])
let result = @moondmn.feel_eval(
  "(function(n: number) external {java:{class: \"Example\", method signature: \"echo(number)\"}})([42])",
  host~,
)
// result 为 JSON 字符串 "42"
```

可运行示例：`moon run examples/host-bridge --target native`；换成 `wasm-gc` 或 `js` 得到相同结果。包导入参考 `examples/host-bridge/moon.pkg`。

`evaluate_decision(model, name, json, host~)` 接收相同注册表。低层类型 API 使用 `feel/eval.register_external(ctx, class, signature, callback)`；FEEL、boxed `functionDefinition kind="Java"` 和 BKM `encapsulatedLogic kind="Java"` 都使用同一桥。boxed Java 函数体为包含 `class` 和 `method signature` 的 DMN context。

未注册时抛出带 class 与 signature 的 `E_EXTERNAL_UNBOUND`；错误描述符抛出 `E_EXTERNAL_DESCRIPTOR`。CLI 不提供回调注册；TCK 的 18 个 JDK 用例继续全部失败。

# MoonDMN｜复审验收

本页对应[本期申报](proposal.md)。各项用实际输入、结果和错误码验收，不用 TCK 总数替代，也不把回调当成 JVM。

| 验收项 | 输入与预期 | 复跑 |
| --- | --- | --- |
| 同模型、同输入，跨后端运行 | 审批模型的收入扣除两笔月供后，净收入 2500 时为 `Approve`，2499.99、1000 和显式空收入时为 `Refer`，999.99 时为 `Decline`。缺字段返回 `E_INPUT_MISSING`，类型错误返回 `E_TYPE`。 | 对 `review_acceptance_test.mbt` 分别运行 Native、Wasm GC、JS 测试。 |
| 业务结果可追溯到规则 | 浏览器构建的实际导出接口执行审批及保费示例，同时校验决策结果与命中规则。 | `scripts/build-web.sh && node web/smoke.mjs` |
| 多文件模型不是简单拼接 | Native CLI 加载独立命名空间中的子模型、类型、可复用函数与决策服务。`examples/imports/input.json` 的 `Shared.Amount=20` 得出 `Total=56`；lint 返回空列表。 | `python3 scripts/test-cli.py` |
| 区分拒绝、忽略和显式注册 | 缺失导入返回 `E_IMPORT_NOT_FOUND`；未绑定 Java 返回 `E_EXTERNAL_UNBOUND`；PMML 返回 `E_DMN_UNSUPPORTED`。DMNDI 不参与求值，不承诺报错。 | CLI、`external_test.mbt`、`dmn/model/r101_23_boxed_function_kind_test.mbt` 与模型解析器。 |

从含配套验收测试的候选源码根目录运行：`bash scripts/review-acceptance.sh`。下面是完整验证的命令。Native、Wasm GC、JS 表示编译目标，不是对 Windows、macOS 分别实测；浏览器核心由 Node 调用编译产物，实际界面可按[快速演示](review-demo.md)核对。

```sh
for target in native wasm-gc js wasm; do
  moon test --target "$target"
done
python3 scripts/test-cli.py
scripts/build-web.sh
node web/smoke.mjs
```

上述验证不覆盖 JVM/JDK、PMML、DMNDI 图形交换或完整 XSD 校验。上游 TCK 的固定基线和未通过用例另见[一致性报告](conformance.md)。

## 固定 TCK 双模式复跑

```sh
./scripts/fetch-tck.sh
reports="$(mktemp -d)"
for level in 2 3; do
  cases=".tck/TestCases/compliance-level-$level"
  moon run cmd/main --target native -- tck "$cases" \
    --now 2026-01-01T00:00:00Z --json "$reports/tck-level-$level.json"
  moon run cmd/main --target native -- tck "$cases" \
    --json "$reports/tck-noclock-$level.json"
done
python3 scripts/verify-review-tck.py "$reports"
```

校验会逐例比较测试身份与结果；不把旧失败换成不同错误算作复审复跑一致。无时钟模式只允许 `now()`、`today()` 各一个固定用例从通过变为无时钟错误。


## 已发布包与候选的区别

- Mooncakes 的 [0.4.0 包](https://download.mooncakes.io/user/sundaysebasidian-byte/moondmn/0.4.0.zip)是已经公开的版本，不包含本次新增验收。已在独立的新消费者项目按固定版本安装，Native、Wasm GC 和 JS 均返回精确结果 `0.3`（表达式 `0.1 + 0.2`）。
- 如果从带 Git 标签的仓库核验包，运行 `python3 scripts/verify-reviewed-package.py /path/to/0.4.0.zip`。脚本核对固定哈希，并将该包内的 201 个 MoonBit 源文件和包清单与 v0.4.0 的 Git 文件逐字节比对。
- Pages、发布包、复审候选分别验证。复审候选的贷款示例修复不是以前已上线的功能，不把它计入公开版的成绩。

# MoonDMN 一致性报告

本报告记录 MoonDMN 对官方 DMN TCK 的本地实测结果。所有用例均执行，无跳过、无修改期望值。

## 环境与方法

- TCK 仓库：https://github.com/dmn-tck/tck
- 固定提交：`1e349176e5ae689d924a2a2c7a8df25c220d8b07`（由 `scripts/fetch-tck.sh` 拉取到被忽略的 `.tck/`）
- 工具链：MoonBit 0.1.20261028，native 后端
- 驱动：`moondmn tck <目录> --json <文件>`，读取 `<modelName>` 指向的模型并按 `resultNode/@type` 分派
- 判定：值结构完全相等为通过；`errorResult="true"` 的用例接受语义错误或 null；其余错误按错误码分类记录

## 汇总

| 级别 | 用例总数 | 通过 | 失败 | 通过率 | 原始报告 |
| --- | --- | --- | --- | --- | --- |
| Level 2 | 116 | 116 | 0 | 100.0% | `evidence/tck-level-2.json` |
| Level 3 | 3291 | 3162 | 129 | 96.08% | `evidence/tck-level-3.json` |

第 3a 阶段目标为 Level 2 不退步、Level 3 ≥ 96%，本次实测达到。

## 失败分类（Level 3）

| 状态码 | 用例数 |
| --- | --- |
| `E_TCK_MISMATCH` | 55 |
| `E_TCK_EXPECTED_ERROR` | 23 |
| `E_UNSUPPORTED_SYNTAX` | 17 |
| `E_IMPORT_UNSUPPORTED` | 6 |
| `E_PARSE` | 6 |
| `E_TYPE` | 4 |
| `E_DMN_ITERATOR` | 4 |
| `E_BUILTIN_UNSUPPORTED` | 4 |
| `E_NAME` | 3 |
| `E_TYPE_UNSUPPORTED` | 2 |
| `E_NUMBER` | 2 |
| `E_DMN_FILTER` | 2 |
| `E_DUPLICATE` | 1 |

说明：`E_TCK_MISMATCH` 表示求值成功但值与期望不同；`E_TCK_EXPECTED_ERROR` 表示期望错误/空值而引擎给出了值；其余为引擎语义错误。

主要失败来源：

- 外部 Java 函数（`0076-feel-external-java`）需要 JVM 回调，明确不实现。
- DMN 1.5 导入（`0086-import`、`1160-multiple-imports`、`0089-nested-inputdata-imports`、`0091-local-hrefs`）尚未实现。
- Unicode 正则与部分匹配语义（`1111-feel-matches-function`、`1109-feel-replace-function`）。
- 动态时间 TCK 未注入运行时钟，仍报不支持；库 API 可注入 clock，CLI 可使用 `--now`。
- `1156-range-function` 的高级参数、区间边界细节与部分隐式转换（`1157-implicit-conversions`）。
- `0103-feel-is-function` 的函数元数据与部分参数适应规则。

## Level 2 全量矩阵（28 个套件，116 例）

| 套件 | 用例 | 通过 | 失败 |
| --- | --- | --- | --- |
| 0001-input-data-string | 1 | 1 | 0 |
| 0002-input-data-number | 1 | 1 | 0 |
| 0003-input-data-string-allowed-values | 1 | 1 | 0 |
| 0004-simpletable-U | 3 | 3 | 0 |
| 0005-simpletable-A | 3 | 3 | 0 |
| 0006-simpletable-P1 | 3 | 3 | 0 |
| 0007-simpletable-P2 | 3 | 3 | 0 |
| 0008-LX-arithmetic | 3 | 3 | 0 |
| 0009-invocation-arithmetic | 3 | 3 | 0 |
| 0010-multi-output-U | 3 | 3 | 0 |
| 0100-feel-constants | 1 | 1 | 0 |
| 0101-feel-constants | 6 | 6 | 0 |
| 0102-feel-constants | 4 | 4 | 0 |
| 0105-feel-math | 33 | 33 | 0 |
| 0106-feel-ternary-logic | 9 | 9 | 0 |
| 0107-feel-ternary-logic-not | 3 | 3 | 0 |
| 0108-first-hitpolicy | 3 | 3 | 0 |
| 0109-ruleOrder-hitpolicy | 3 | 3 | 0 |
| 0110-outputOrder-hitpolicy | 3 | 3 | 0 |
| 0111-first-hitpolicy-singleoutputcol | 3 | 3 | 0 |
| 0112-ruleOrder-hitpolicy-singleinoutcol | 3 | 3 | 0 |
| 0113-outputOrder-hitpolicy-singleinoutcol | 3 | 3 | 0 |
| 0114-min-collect-hitpolicy | 3 | 3 | 0 |
| 0115-sum-collect-hitpolicy | 3 | 3 | 0 |
| 0116-count-collect-hitpolicy | 3 | 3 | 0 |
| 0117-multi-any-hitpolicy | 3 | 3 | 0 |
| 0118-multi-priority-hitpolicy | 3 | 3 | 0 |
| 0119-multi-collect-hitpolicy | 3 | 3 | 0 |

## Level 3 全量矩阵（120 个套件，3291 例）

| 套件 | 用例 | 通过 | 失败 |
| --- | --- | --- | --- |
| 0001-filter | 1 | 1 | 0 |
| 0002-string-functions | 4 | 4 | 0 |
| 0003-iteration | 1 | 1 | 0 |
| 0004-lending | 1 | 0 | 1 |
| 0005-literal-invocation | 3 | 3 | 0 |
| 0006-join | 1 | 1 | 0 |
| 0007-date-time | 1 | 1 | 0 |
| 0008-listGen | 10 | 10 | 0 |
| 0009-append-flatten | 1 | 1 | 0 |
| 0010-concatenate | 1 | 1 | 0 |
| 0011-insert-remove | 1 | 1 | 0 |
| 0012-list-functions | 19 | 19 | 0 |
| 0013-sort | 1 | 0 | 1 |
| 0014-loan-comparison | 1 | 1 | 0 |
| 0016-some-every | 3 | 3 | 0 |
| 0017-tableTests | 4 | 4 | 0 |
| 0020-vacation-days | 7 | 2 | 5 |
| 0021-singleton-list | 1 | 0 | 1 |
| 0030-user-defined-functions | 1 | 1 | 0 |
| 0031-user-defined-functions | 3 | 3 | 0 |
| 0032-conditionals | 6 | 6 | 0 |
| 0033-for-loops | 4 | 4 | 0 |
| 0034-drg-scopes | 1 | 1 | 0 |
| 0035-test-structure-output | 3 | 3 | 0 |
| 0036-dt-variable-input | 3 | 1 | 2 |
| 0037-dt-on-bkm-implicit-params | 2 | 2 | 0 |
| 0038-dt-on-bkm-explicit-params | 2 | 2 | 0 |
| 0039-dt-list-semantics | 2 | 2 | 0 |
| 0040-singlenestedcontext | 3 | 3 | 0 |
| 0041-multiple-nestedcontext | 3 | 3 | 0 |
| 0050-feel-abs-function | 17 | 17 | 0 |
| 0051-feel-sqrt-function | 15 | 15 | 0 |
| 0052-feel-exp-function | 15 | 15 | 0 |
| 0053-feel-log-function | 15 | 15 | 0 |
| 0054-feel-even-function | 17 | 17 | 0 |
| 0055-feel-odd-function | 17 | 17 | 0 |
| 0056-feel-modulo-function | 28 | 28 | 0 |
| 0057-feel-context | 11 | 8 | 3 |
| 0058-feel-number-function | 21 | 19 | 2 |
| 0059-feel-all-function | 19 | 19 | 0 |
| 0060-feel-any-function | 17 | 17 | 0 |
| 0061-feel-median-function | 14 | 14 | 0 |
| 0062-feel-mode-function | 13 | 13 | 0 |
| 0063-feel-stddev-function | 12 | 12 | 0 |
| 0064-feel-conjunction | 19 | 19 | 0 |
| 0065-feel-disjunction | 19 | 19 | 0 |
| 0066-feel-negation | 6 | 6 | 0 |
| 0067-feel-split-function | 9 | 8 | 1 |
| 0068-feel-equality | 114 | 113 | 1 |
| 0069-feel-list | 35 | 32 | 3 |
| 0070-feel-instance-of | 142 | 141 | 1 |
| 0071-feel-between | 38 | 38 | 0 |
| 0072-feel-in | 327 | 325 | 2 |
| 0073-feel-comments | 3 | 3 | 0 |
| 0074-feel-properties | 53 | 53 | 0 |
| 0075-feel-exponent | 12 | 11 | 1 |
| 0076-feel-external-java | 18 | 0 | 18 |
| 0077-feel-nan | 1 | 1 | 0 |
| 0078-feel-infinity | 2 | 2 | 0 |
| 0080-feel-getvalue-function | 14 | 14 | 0 |
| 0081-feel-getentries-function | 9 | 9 | 0 |
| 0082-feel-coercion | 36 | 24 | 12 |
| 0083-feel-unicode | 14 | 12 | 2 |
| 0084-feel-for-loops | 24 | 19 | 5 |
| 0085-decision-services | 18 | 15 | 3 |
| 0086-import | 2 | 0 | 2 |
| 0087-chapter-11-example | 8 | 3 | 5 |
| 0088-no-decision-logic | 1 | 1 | 0 |
| 0089-nested-inputdata-imports | 1 | 0 | 1 |
| 0090-feel-paths | 4 | 4 | 0 |
| 0091-local-hrefs | 1 | 0 | 1 |
| 0092-feel-lambda | 18 | 18 | 0 |
| 0093-feel-at-literals | 19 | 19 | 0 |
| 0094-feel-product-function | 13 | 13 | 0 |
| 0095-feel-day-of-year-function | 19 | 19 | 0 |
| 0096-feel-day-of-week-function | 12 | 12 | 0 |
| 0097-feel-month-of-year-function | 12 | 12 | 0 |
| 0098-feel-week-of-year-function | 19 | 19 | 0 |
| 0099-arithmetic-negation | 14 | 14 | 0 |
| 0100-arithmetic | 1087 | 1084 | 3 |
| 0103-feel-is-function | 50 | 48 | 2 |
| 1100-feel-decimal-function | 10 | 10 | 0 |
| 1101-feel-floor-function | 17 | 17 | 0 |
| 1102-feel-ceiling-function | 17 | 17 | 0 |
| 1103-feel-substring-function | 11 | 10 | 1 |
| 1104-feel-string-length-function | 6 | 6 | 0 |
| 1105-feel-upper-case-function | 8 | 8 | 0 |
| 1106-feel-lower-case-function | 9 | 9 | 0 |
| 1107-feel-substring-before-function | 9 | 9 | 0 |
| 1108-feel-substring-after-function | 10 | 10 | 0 |
| 1109-feel-replace-function | 28 | 28 | 0 |
| 1110-feel-contains-function | 10 | 10 | 0 |
| 1111-feel-matches-function | 40 | 31 | 9 |
| 1115-feel-date-function | 52 | 50 | 2 |
| 1116-feel-time-function | 83 | 77 | 6 |
| 1117-feel-date-and-time-function | 88 | 86 | 2 |
| 1120-feel-duration-function | 50 | 50 | 0 |
| 1121-feel-years-and-months-duration-function | 36 | 36 | 0 |
| 1130-feel-interval | 14 | 8 | 6 |
| 1131-feel-function-invocation | 8 | 7 | 1 |
| 1140-feel-string-join-function | 22 | 20 | 2 |
| 1141-feel-round-up-function | 16 | 16 | 0 |
| 1142-feel-round-down-function | 16 | 16 | 0 |
| 1143-feel-round-half-up-function | 16 | 16 | 0 |
| 1144-feel-round-half-down-function | 16 | 16 | 0 |
| 1145-feel-context-function | 18 | 18 | 0 |
| 1146-feel-context-put-function | 30 | 29 | 1 |
| 1147-feel-context-merge-function | 14 | 14 | 0 |
| 1148-feel-now-function | 2 | 0 | 2 |
| 1149-feel-today-function | 2 | 0 | 2 |
| 1150-boxed-conditional | 3 | 2 | 1 |
| 1151-boxed-filter | 4 | 2 | 2 |
| 1152-boxed-for | 2 | 2 | 0 |
| 1153-boxed-some | 5 | 3 | 2 |
| 1154-boxed-every | 5 | 3 | 2 |
| 1155-list-replace-function | 22 | 22 | 0 |
| 1156-range-function | 56 | 56 | 0 |
| 1157-implicit-conversions | 12 | 6 | 6 |
| 1160-multiple-imports | 4 | 0 | 4 |
| 1161-boxed-list-expression | 2 | 2 | 0 |

## 复现

```bash
export PATH="$HOME/.moon/bin:$PATH"
./scripts/fetch-tck.sh
moon run cmd/main --target native -- tck .tck/TestCases/compliance-level-2 --json evidence/tck-level-2.json
moon run cmd/main --target native -- tck .tck/TestCases/compliance-level-3 --json evidence/tck-level-3.json
```

作为人工核对，可直接运行不写文件的模式：

```bash
moon run cmd/main --target native -- tck .tck/TestCases/compliance-level-3/0068-feel-equality
```


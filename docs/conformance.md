# MoonDMN 一致性报告

本报告记录 MoonDMN 对官方 DMN TCK 的本地实测结果。所有用例均执行，无跳过、无修改期望值。

<!-- summary:start -->
## 结论

Level 2 为 116/116。Level 3 为 3251/3291（98.78%），剩余 40 个失败，没有跳过，也没有被隐藏的用例。

这 40 个失败里，7 个（18%）是引擎自己的缺陷，29 个属于范围外或测试环境。通过率不能理解为“剩下的都是范围外”。

| 分类 | 失败数 | 占失败比例 | 含义 |
| --- | ---: | ---: | --- |
| 已知缺陷 | 7 | 17.5% | 范围内的行为不正确，是待修的缺陷 |
| 未实现 | 25 | 62.5% | 尚未实现或明确不做 |
| 覆盖边界 | 2 | 5.0% | 实现主动拒绝，不猜测 |
| 规范与 TCK 存在差异 | 2 | 5.0% | 实现依据规范文本，与 TCK 期望不一致；仍计为失败 |
| 驱动未提供时钟 | 4 | 10.0% | TCK 驱动不提供时钟；API 与 CLI 注入时钟后可用 |

未实现的 25 个中，Java 外部函数 18 个，DMN `import` 7 个。

已知缺陷集中在下面这些套件（按失败数排序，只列前 10 个；全部明细见文末）：

| 套件 | 失败数 | 症状举例 |
| --- | ---: | --- |
| 1111-feel-matches-function | 6 | 剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。 |
| 0068-feel-equality | 1 | 比较式 (=x) 被表示为双闭点区间，丢失一元测试与双端区间的类型区别；需扩展值表示和相等规则。 |

数字的来源：

- 全部 3291 个用例都真实执行；runner、数值比较容差和上游期望值都没有为了提高通过率而修改。
- 失败清单可机读：`evidence/failure-classification.json`，每行以测试文件路径加 case ID 唯一标识；逐例原始报告是 `evidence/tck-level-*.json`。
- 任何一个套件都可以用下文“复现”一节的命令单独重跑。
<!-- summary:end -->

## 时态算术边界核验（0.1.0 记录）

N1 及同类时态整数窄化风险已修复：日期月份先用 Int64，duration/epoch 纳秒在 BigInt 中计算，越界返回 E_DATE_RANGE 或 E_DURATION_RANGE。相关回归测试已并入各后端的测试集；两级 TCK 数字未变。逐项排查依据、容量范围和测试见 [时态算术核验](temporal-arithmetic.md)。0.1.1 的语义修正和当前 TCK 数字见上文。

## 0.1.1 语义修正与边界

依据 [DMN 1.5](https://www.omg.org/spec/DMN/1.5/PDF) §10.3.2、§10.3.4、§10.4 的求值、内建函数和 invocable 语义，补充 31 个独立测试块。测试不依赖 TCK 文件，期望值为固定的规范结果。

补充类型化函数的单元素列表包装、date 到 UTC 午夜转换，以及按 AST 中 `?` 引用判定布尔一元谓词；新增 2 个回归测试块包含无 `?` 的比较与函数调用、嵌套 `?`、不兼容参数、已有列表及嵌套列表。验收命令及输出见 `evidence/invocation-unary-validation/commands.json`。

L2 保持 116/116；L3 从 3170/3291、121 个失败变为 3251/3291、40 个失败。runner 的比较规则、容差及错误白名单完全未改。

剩余项暂不修复的原因：

- Java 外部函数 18：需要 JVM/宿主调用桥，当前纯 MoonBit 引擎不提供。
- 跨文件 import 7：需要文件解析接口、目录内相对模型引用、别名与命名空间隔离；本版本只支持本模型 namespace 的绝对 href，不把它当成跨文件 import 支持。
- Unicode/XPath 正则 6：底层正则缺少完整 Unicode 大小写折叠、字符类相减和反向引用；需要独立实现或更换兼容的正则基础。
- 比较式区间相等 1：当前值表示丢失一元测试与双端区间的区别，需扩展表示及相等规则。
- 小数秒相等 2：保留精度，规范/TCK 差异仍待核对，不为通过测试丢弃小数秒。
- 无日期命名时区 time 相减 2：DST offset 无法唯一确定，继续明确拒绝。
- now()/today() 4：驱动未注入时钟，按要求继续失败并披露。

解析器 AST 增加 TypedFunctionDef 以保留类型声明；直接穷举 Expr 的调用方需补充分支。FEEL 调用与顶层决策的类型不匹配现在产生 null，基础 API 的其他显式错误仍保留错误码。

## 环境与方法

- TCK 仓库：https://github.com/dmn-tck/tck
- 固定提交：`1e349176e5ae689d924a2a2c7a8df25c220d8b07`（由 `scripts/fetch-tck.sh` 拉取到被忽略的 `.tck/`）
- 工具链：MoonBit 0.1.20261028，native 后端
- 驱动：`moondmn tck <目录> --json <文件>`，读取 `<modelName>` 指向的模型并按 `resultNode/@type` 分派
- 判定：number 使用绝对差 ≤ 1e-8，list/context 递归比较，其他值使用引擎结构/时态相等；errorResult 只接受现有白名单错误或期望 null 时的 null。未改 runner 或容差

## 汇总

| 级别 | 用例总数 | 通过 | 失败 | 通过率 | 原始报告 |
| --- | --- | --- | --- | --- | --- |
| Level 2 | 116 | 116 | 0 | 100.00% | `evidence/tck-level-2.json` |
| Level 3 | 3291 | 3251 | 40 | 98.78% | `evidence/tck-level-3.json` |

目标为 Level 2 ≥ 95%、Level 3 ≥ 80%，两项均已达到。

## 测试规模

- 单元测试 273 个 test block，native、wasm-gc、js、wasm 四个目标各 273/273 通过；另有 16 项 CLI 进程级检查（`scripts/test-cli.py`）。
- MoonBit 代码共 14581 行，其中自动生成的 tzdata 4394 行、whitebox 测试 38 行；排除这两部分后为 10149 行。
- 测试期望值由人工给定；另有独立 Python decimal128 oracle 验证 120 组带固定种子的四则运算。另有 1200 次 XML 截断/变异测试（固定种子），Playground 冒烟测试 26 项。
- 4 个动态时间用例（`1148-feel-now-function`、`1149-feel-today-function`）因 TCK 驱动不提供时钟而失败；API 与 CLI 注入时钟后 `now()`、`today()` 可用。

## 失败状态码（Level 3）

| 状态码 | 用例数 |
| --- | --- |
| `E_UNSUPPORTED_SYNTAX` | 17 |
| `E_TCK_MISMATCH` | 10 |
| `E_IMPORT_UNSUPPORTED` | 5 |
| `E_BUILTIN_UNSUPPORTED` | 4 |
| `E_TYPE_UNSUPPORTED` | 2 |
| `E_ZONE_UNSUPPORTED` | 2 |

下表按引擎返回的状态码统计，和上面“结论”里按原因的分类是两个维度。`E_TCK_MISMATCH` 表示求值成功但值与期望不同；`E_TCK_EXPECTED_ERROR` 表示期望错误/空值而引擎给出了值；其余为引擎语义错误。

几个主要的失败来源（不是全部，全部见文末逐例明细）：

- 外部 Java 函数（`0076-feel-external-java`）需要 JVM 回调，明确不实现。
- DMN 1.5 导入（`0086-import`、`1160-multiple-imports`、`0089-nested-inputdata-imports`）尚未实现。
- Unicode 正则与部分匹配语义（`1111-feel-matches-function`）。
- 动态时间 TCK 未注入运行时钟，仍报不支持；库 API 可注入 clock，CLI 可使用 `--now`。
- 比较式区间与双端区间的值表示差异（`0068-feel-equality/range_010`）。

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
| 0004-lending | 1 | 1 | 0 |
| 0005-literal-invocation | 3 | 3 | 0 |
| 0006-join | 1 | 1 | 0 |
| 0007-date-time | 1 | 1 | 0 |
| 0008-listGen | 10 | 10 | 0 |
| 0009-append-flatten | 1 | 1 | 0 |
| 0010-concatenate | 1 | 1 | 0 |
| 0011-insert-remove | 1 | 1 | 0 |
| 0012-list-functions | 19 | 19 | 0 |
| 0013-sort | 1 | 1 | 0 |
| 0014-loan-comparison | 1 | 1 | 0 |
| 0016-some-every | 3 | 3 | 0 |
| 0017-tableTests | 4 | 4 | 0 |
| 0020-vacation-days | 7 | 7 | 0 |
| 0021-singleton-list | 1 | 1 | 0 |
| 0030-user-defined-functions | 1 | 1 | 0 |
| 0031-user-defined-functions | 3 | 3 | 0 |
| 0032-conditionals | 6 | 6 | 0 |
| 0033-for-loops | 4 | 4 | 0 |
| 0034-drg-scopes | 1 | 1 | 0 |
| 0035-test-structure-output | 3 | 3 | 0 |
| 0036-dt-variable-input | 3 | 3 | 0 |
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
| 0057-feel-context | 11 | 11 | 0 |
| 0058-feel-number-function | 21 | 21 | 0 |
| 0059-feel-all-function | 19 | 19 | 0 |
| 0060-feel-any-function | 17 | 17 | 0 |
| 0061-feel-median-function | 14 | 14 | 0 |
| 0062-feel-mode-function | 13 | 13 | 0 |
| 0063-feel-stddev-function | 12 | 12 | 0 |
| 0064-feel-conjunction | 19 | 19 | 0 |
| 0065-feel-disjunction | 19 | 19 | 0 |
| 0066-feel-negation | 6 | 6 | 0 |
| 0067-feel-split-function | 9 | 9 | 0 |
| 0068-feel-equality | 114 | 111 | 3 |
| 0069-feel-list | 35 | 35 | 0 |
| 0070-feel-instance-of | 142 | 142 | 0 |
| 0071-feel-between | 38 | 38 | 0 |
| 0072-feel-in | 327 | 327 | 0 |
| 0073-feel-comments | 3 | 3 | 0 |
| 0074-feel-properties | 53 | 53 | 0 |
| 0075-feel-exponent | 12 | 12 | 0 |
| 0076-feel-external-java | 18 | 0 | 18 |
| 0077-feel-nan | 1 | 1 | 0 |
| 0078-feel-infinity | 2 | 2 | 0 |
| 0080-feel-getvalue-function | 14 | 14 | 0 |
| 0081-feel-getentries-function | 9 | 9 | 0 |
| 0082-feel-coercion | 36 | 36 | 0 |
| 0083-feel-unicode | 14 | 14 | 0 |
| 0084-feel-for-loops | 24 | 24 | 0 |
| 0085-decision-services | 18 | 18 | 0 |
| 0086-import | 2 | 0 | 2 |
| 0087-chapter-11-example | 8 | 8 | 0 |
| 0088-no-decision-logic | 1 | 1 | 0 |
| 0089-nested-inputdata-imports | 1 | 0 | 1 |
| 0090-feel-paths | 4 | 4 | 0 |
| 0091-local-hrefs | 1 | 1 | 0 |
| 0092-feel-lambda | 18 | 18 | 0 |
| 0093-feel-at-literals | 19 | 19 | 0 |
| 0094-feel-product-function | 13 | 13 | 0 |
| 0095-feel-day-of-year-function | 19 | 19 | 0 |
| 0096-feel-day-of-week-function | 12 | 12 | 0 |
| 0097-feel-month-of-year-function | 12 | 12 | 0 |
| 0098-feel-week-of-year-function | 19 | 19 | 0 |
| 0099-arithmetic-negation | 14 | 14 | 0 |
| 0100-arithmetic | 1087 | 1085 | 2 |
| 0103-feel-is-function | 50 | 50 | 0 |
| 1100-feel-decimal-function | 10 | 10 | 0 |
| 1101-feel-floor-function | 17 | 17 | 0 |
| 1102-feel-ceiling-function | 17 | 17 | 0 |
| 1103-feel-substring-function | 11 | 11 | 0 |
| 1104-feel-string-length-function | 6 | 6 | 0 |
| 1105-feel-upper-case-function | 8 | 8 | 0 |
| 1106-feel-lower-case-function | 9 | 9 | 0 |
| 1107-feel-substring-before-function | 9 | 9 | 0 |
| 1108-feel-substring-after-function | 10 | 10 | 0 |
| 1109-feel-replace-function | 28 | 28 | 0 |
| 1110-feel-contains-function | 10 | 10 | 0 |
| 1111-feel-matches-function | 40 | 34 | 6 |
| 1115-feel-date-function | 52 | 52 | 0 |
| 1116-feel-time-function | 83 | 83 | 0 |
| 1117-feel-date-and-time-function | 88 | 88 | 0 |
| 1120-feel-duration-function | 50 | 50 | 0 |
| 1121-feel-years-and-months-duration-function | 36 | 36 | 0 |
| 1130-feel-interval | 14 | 14 | 0 |
| 1131-feel-function-invocation | 8 | 8 | 0 |
| 1140-feel-string-join-function | 22 | 22 | 0 |
| 1141-feel-round-up-function | 16 | 16 | 0 |
| 1142-feel-round-down-function | 16 | 16 | 0 |
| 1143-feel-round-half-up-function | 16 | 16 | 0 |
| 1144-feel-round-half-down-function | 16 | 16 | 0 |
| 1145-feel-context-function | 18 | 18 | 0 |
| 1146-feel-context-put-function | 30 | 30 | 0 |
| 1147-feel-context-merge-function | 14 | 14 | 0 |
| 1148-feel-now-function | 2 | 0 | 2 |
| 1149-feel-today-function | 2 | 0 | 2 |
| 1150-boxed-conditional | 3 | 3 | 0 |
| 1151-boxed-filter | 4 | 4 | 0 |
| 1152-boxed-for | 2 | 2 | 0 |
| 1153-boxed-some | 5 | 5 | 0 |
| 1154-boxed-every | 5 | 5 | 0 |
| 1155-list-replace-function | 22 | 22 | 0 |
| 1156-range-function | 56 | 56 | 0 |
| 1157-implicit-conversions | 12 | 12 | 0 |
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

## 已修复的问题与明确边界

| 项目 | 状态与证据 |
| --- | --- |
| 畸形 conditional | 已修复 conditional 必需分支缺失/重复触发 trap；先检查 if/then/else，再惰性求值。所有已查模型数组访问均有长度/存在性约束；非完整 XSD 验证器。原生/三后端 1200 次变异和 JS 缺三种分支回归均通过；补修负年份 weekday 的负数组下标和日历换算 Int32 中间值溢出，另有 49 组日历 round-trip 检查。 |
| 点路径多词名称 | 路径在 context 已知键中做最长匹配；literal context 多词/运算符键也可用。未知多词字段不猜测。静态 compile 缺少运行时 context 时须在 names 提供作用域名称/字段名。 |
| JSON 时态输入 | `@model.json_inputs` 是根包、CLI、Playground 的唯一声明 JSON 时态转换入口；递归处理 alias/context/collection/null，非法字符串抛错误，不把 FEEL string 自动当 date。 |
| Decimal128 范围 | 34 位系数，scale [-6111,6176]；最大 adjusted exponent 6144，最小非零 1e-6176，渐进下溢与 half-even。库溢出抛 E_DECIMAL_RANGE，FEEL 四则非有限结果为 null。sqrt/log/exp/非整数幂仍有浮点桥接限制，不宣称全部数值内置函数都是精确 Decimal128。 |
| 命名参数缺省 | 用户函数/BKM 与内置函数的命名缺参绑定 null；位置缺参、混用、未知/重复名称被拒绝。可选重载按签名区分，例如 floor(n) 与显式 scale:null。 |
| IANA 时区子集 | 部分支持：下面列出 39 个名称；数据来自本机 TZif 2026e（指纹已记录），并非完整 IANA 包。偏移计算使用完整本地时刻；gap 返回 E_ZONE_GAP，overlap 选择较早 UTC 时刻。日期/时刻边界见下文。 |
| lint 覆盖证明 | inputValues 与 ItemDefinition allowedValues/alias 可推导有限域时穷举覆盖；最多 4096 个输入组合。可证明时不报 gap；未知/开放域、错误谓词、超过上限时保留告警。重复规则仍单独告警。 |
| 许可声明 | NOTICE 分开说明 TCK Apache 材料和上游 README 声明的 CC 署名/相同方式共享测试用例。上游没有指明 CC 版本，未自行推定。TCK 仍只在忽略缓存中下载。 |

### 时区数据范围

- 生成器：`python3 scripts/generate-tzdata.py /usr/share/zoneinfo`；要求 `+VERSION` 为 2026e，来源指纹见 `scripts/tzdata-sources.json`。其他系统可用同版本 IANA 源经 zic 构建 TZif 目录再生成。数据许可见 NOTICE 和 [IANA 数据说明](https://data.iana.org/time-zones/tz-link.html)。
- UTC 窗口为 `[1970-01-01T00:00:00Z,2101-01-01T00:00:00Z)`，解析偏移时本地年份也要求 1970–2100；窗口端点附近可能因偏移越界而拒绝。超范围 E_ZONE_RANGE / 边界不可解析 E_ZONE_GAP；未知名称 E_ZONE_UNSUPPORTED。内置函数把这些无效参数转换为 FEEL null，核心解析/求值入口仍返回可匹配错误。
- 超范围年份可保留为本地日历值并做不需要偏移的本地计算，但不能据此解析 IANA instant。只有名称、没有日期的 time：同名同本地时间可判相等；需要 DST 偏移的相减/跨区比较明确拒绝，不假设参考日期。
- 时刻存储为纳秒。TCK 中两条“忽略毫秒”期望与当前基于 DMN 1.5 decimal second 的实现不一致，仍计失败并待上游确认。不是通过放宽比较器消除差异。
- 未来规则是 2026e 的投影，政策变化需要显式更新数据；运行时不依赖本机 zoneinfo。DST 年月算术、极端年份和部分时间构造仍有已列出的语义缺口，不把此子集标为完整时区支持。

名称（含 UT/Z 兼容别名）：

`UTC`, `Etc/UTC`, `GMT`, `Etc/GMT`, `Z`, `UT`, `Europe/Paris`, `Europe/Berlin`, `Europe/Madrid`, `Europe/Rome`, `Europe/Amsterdam`, `Europe/Brussels`, `Europe/Vienna`, `Europe/Stockholm`, `Europe/Oslo`, `Europe/Copenhagen`, `Europe/Zurich`, `Europe/London`, `Europe/Lisbon`, `Europe/Dublin`, `Asia/Dhaka`, `Asia/Kolkata`, `Asia/Calcutta`, `Asia/Karachi`, `Asia/Tokyo`, `Asia/Shanghai`, `Asia/Hong_Kong`, `Asia/Singapore`, `America/New_York`, `America/Toronto`, `America/Chicago`, `America/Los_Angeles`, `America/Vancouver`, `America/Mexico_City`, `Australia/Sydney`, `Australia/Melbourne`, `Australia/Brisbane`, `Australia/Perth`, `Pacific/Auckland`

## 逐例明细

每一行是一个失败用例，共 40 行；分类不改变通过或失败的结果。“已知缺陷”包含已确认但尚未修复的不一致，原因逐项注明。

| 套件 / 测试文件 | case ID | 分类 | 原因 |
| --- | --- | --- | --- |
| 0068-feel-equality/0068-feel-equality-test-01.xml | `datetime_003_a` | 规范与 TCK 存在差异 | TCK 描述要求忽略毫秒并判相等；实现保留小数秒，返回 false。DMN 1.5 §10.3.2.3.4/.6 的 valuet/valuedt 单射与表 66 的 decimal second 语义支持保留精度；需向上游核对该旧期望，当前仍计失败。 |
| 0068-feel-equality/0068-feel-equality-test-01.xml | `range_010` | 已知缺陷 | 比较式 (=x) 被表示为双闭点区间，丢失一元测试与双端区间的类型区别；需扩展值表示和相等规则。 |
| 0068-feel-equality/0068-feel-equality-test-01.xml | `time_005` | 规范与 TCK 存在差异 | TCK 描述要求忽略毫秒并判相等；实现保留小数秒，返回 false。DMN 1.5 §10.3.2.3.4/.6 的 valuet/valuedt 单射与表 66 的 decimal second 语义支持保留精度；需向上游核对该旧期望，当前仍计失败。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `boxed_001` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `incorrect_001` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `incorrect_002` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `incorrect_003` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_001` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_002` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_003` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_004` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_005` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_006` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_007` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_007_a` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_008` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_009` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_010` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_011` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `literal_012` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0076-feel-external-java/0076-feel-external-java-test-01.xml | `varargs_001` | 未实现 | Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。 |
| 0086-import/0086-import-test-01.xml | `test_001` | 未实现 | 跨文件 import 的名称解析和导入 ItemDefinition 注册未实现。 |
| 0086-import/0086-import-test-01.xml | `test_002` | 未实现 | 跨文件 import 的名称解析和导入 ItemDefinition 注册未实现。 |
| 0089-nested-inputdata-imports/0089-nested-inputdata-imports-test-01.xml | `001` | 未实现 | 嵌套导入的 InputData/href 解析未实现。 |
| 0100-arithmetic/0100-arithmetic-test-01.xml | `subtract_lhs_time_minus_rhs_time_005` | 覆盖边界 | time 只有 IANA 名称而没有日期，不能唯一计算 Melbourne 的 DST 偏移；显式拒绝该相减，不猜测参考日期。 |
| 0100-arithmetic/0100-arithmetic-test-01.xml | `subtract_lhs_time_minus_rhs_time_006` | 覆盖边界 | time 只有 IANA 名称而没有日期，不能唯一计算 Melbourne 的 DST 偏移；显式拒绝该相减，不猜测参考日期。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `K2-MatchesFunc-17` | 已知缺陷 | 剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch07` | 已知缺陷 | 剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch08` | 已知缺陷 | 剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch09` | 已知缺陷 | 剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch10` | 已知缺陷 | 剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch11` | 已知缺陷 | 剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。 |
| 1148-feel-now-function/1148-feel-now-function-test-01.xml | `001` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1148-feel-now-function/1148-feel-now-function-test-01.xml | `002` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1149-feel-today-function/1149-feel-today-function-test-01.xml | `001` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1149-feel-today-function/1149-feel-today-function-test-01.xml | `002` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1160-multiple-imports/1160-multiple-imports-test-01.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |
| 1160-multiple-imports/1160-multiple-imports-test-02.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |
| 1160-multiple-imports/1160-multiple-imports-test-03.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |
| 1160-multiple-imports/1160-multiple-imports-test-04.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |

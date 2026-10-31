# MoonDMN 一致性报告

本报告记录 MoonDMN 对官方 DMN TCK 的本地实测结果。所有用例均执行，无跳过、无修改期望值。

<!-- summary:start -->
## 结论

Level 2 为 116/116。Level 3 为 3170/3291（96.32%），剩余 121 个失败，没有跳过，也没有被隐藏的用例。

这 121 个失败里，87 个（72%）是引擎自己的缺陷，只有 30 个属于范围外或测试环境。通过率不能理解为“剩下的都是范围外”。

| 分类 | 失败数 | 占失败比例 | 含义 |
| --- | ---: | ---: | --- |
| 已知缺陷 | 87 | 71.9% | 范围内的行为不正确，是待修的缺陷 |
| 未实现 | 26 | 21.5% | 尚未实现或明确不做 |
| 覆盖边界 | 2 | 1.7% | 实现主动拒绝，不猜测 |
| 规范与 TCK 存在差异 | 2 | 1.7% | 实现依据规范文本，与 TCK 期望不一致；仍计为失败 |
| 驱动未提供时钟 | 4 | 3.3% | TCK 驱动不提供时钟；API 与 CLI 注入时钟后可用 |

未实现的 26 个中，Java 外部函数 18 个，DMN `import` 8 个。

已知缺陷集中在下面这些套件（按失败数排序，只列前 10 个；全部明细见文末）：

| 套件 | 失败数 | 症状举例 |
| --- | ---: | --- |
| 0082-feel-coercion | 12 | 结构化字段缺失被补成 null 后接受，与该声明类型要求的错误/null 不一致。 |
| 1111-feel-matches-function | 9 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1130-feel-interval | 6 | 同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。 |
| 1157-implicit-conversions | 6 | 决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。 |
| 0020-vacation-days | 5 | 休假天数决策链返回 null 而非数字；表调用与传播路径的直接根因待定位。 |
| 0084-feel-for-loops | 5 | 非法 range domain 或 range/list 迭代区分不正确：本应 null/错误，却返回列表。 |
| 0087-chapter-11-example | 5 | 综合信贷示例的风险/路由决策结果错误；直接根因尚未完全定位，不能声称规范歧义。 |
| 0069-feel-list | 3 | item 字段被注入的整个 item context 遮蔽，导致 context 与 number 比较。 |
| 0100-arithmetic | 3 | date 与 date-time 混合相减未拒绝不兼容类型。 |
| 0085-decision-services | 3 | 服务位置参数按 href 排序绑定，未按声明输入参数次序绑定。 |

数字的来源：

- 全部 3291 个用例都真实执行；runner、数值比较容差和上游期望值都没有为了提高通过率而修改。
- 失败清单可机读：`evidence/failure-classification.json`，每行以测试文件路径加 case ID 唯一标识；逐例原始报告是 `evidence/tck-level-*.json`。
- 任何一个套件都可以用下文“复现”一节的命令单独重跑。
<!-- summary:end -->

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
| Level 3 | 3291 | 3170 | 121 | 96.32% | `evidence/tck-level-3.json` |

目标为 Level 2 ≥ 95%、Level 3 ≥ 80%，两项均已达到。

## 测试规模

- 单元测试 224 个 test block，native、wasm-gc、js 三个后端各 224/224 通过；另有 12 项 CLI 进程级检查（`scripts/test-cli.py`）。
- MoonBit 代码共 14217 行，其中自动生成的 tzdata 4394 行、whitebox 测试 38 行；排除这两部分后为 9785 行。
- 测试期望值由人工给定；另有独立 Python decimal128 oracle 验证 120 组带固定种子的四则运算。另有 1200 次 XML 截断/变异测试（固定种子），Playground 冒烟测试 25 项。
- 4 个动态时间用例（`1148-feel-now-function`、`1149-feel-today-function`）因 TCK 驱动不提供时钟而失败；API 与 CLI 注入时钟后 `now()`、`today()` 可用。

## 失败状态码（Level 3）

| 状态码 | 用例数 |
| --- | --- |
| `E_TCK_MISMATCH` | 54 |
| `E_TCK_EXPECTED_ERROR` | 19 |
| `E_UNSUPPORTED_SYNTAX` | 17 |
| `E_IMPORT_UNSUPPORTED` | 6 |
| `E_TYPE` | 4 |
| `E_DMN_ITERATOR` | 4 |
| `E_BUILTIN_UNSUPPORTED` | 4 |
| `E_NAME` | 3 |
| `E_PARSE` | 3 |
| `E_TYPE_UNSUPPORTED` | 2 |
| `E_ZONE_UNSUPPORTED` | 2 |
| `E_DMN_FILTER` | 2 |
| `E_DUPLICATE` | 1 |

下表按引擎返回的状态码统计，和上面“结论”里按原因的分类是两个维度。`E_TCK_MISMATCH` 表示求值成功但值与期望不同；`E_TCK_EXPECTED_ERROR` 表示期望错误/空值而引擎给出了值；其余为引擎语义错误。

几个主要的失败来源（不是全部，全部见文末逐例明细）：

- 外部 Java 函数（`0076-feel-external-java`）需要 JVM 回调，明确不实现。
- DMN 1.5 导入（`0086-import`、`1160-multiple-imports`、`0089-nested-inputdata-imports`、`0091-local-hrefs`）尚未实现。
- Unicode 正则与部分匹配语义（`1111-feel-matches-function`）。
- 动态时间 TCK 未注入运行时钟，仍报不支持；库 API 可注入 clock，CLI 可使用 `--now`。
- `1130-feel-interval` 的开闭端点关系与 `1157-implicit-conversions` 的隐式转换。

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
| 0057-feel-context | 11 | 10 | 1 |
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
| 0068-feel-equality | 114 | 111 | 3 |
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
| 0100-arithmetic | 1087 | 1082 | 5 |
| 0103-feel-is-function | 50 | 50 | 0 |
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
| 1115-feel-date-function | 52 | 51 | 1 |
| 1116-feel-time-function | 83 | 80 | 3 |
| 1117-feel-date-and-time-function | 88 | 87 | 1 |
| 1120-feel-duration-function | 50 | 50 | 0 |
| 1121-feel-years-and-months-duration-function | 36 | 36 | 0 |
| 1130-feel-interval | 14 | 8 | 6 |
| 1131-feel-function-invocation | 8 | 7 | 1 |
| 1140-feel-string-join-function | 22 | 22 | 0 |
| 1141-feel-round-up-function | 16 | 16 | 0 |
| 1142-feel-round-down-function | 16 | 16 | 0 |
| 1143-feel-round-half-up-function | 16 | 16 | 0 |
| 1144-feel-round-half-down-function | 16 | 16 | 0 |
| 1145-feel-context-function | 18 | 18 | 0 |
| 1146-feel-context-put-function | 30 | 29 | 1 |
| 1147-feel-context-merge-function | 14 | 14 | 0 |
| 1148-feel-now-function | 2 | 0 | 2 |
| 1149-feel-today-function | 2 | 0 | 2 |
| 1150-boxed-conditional | 3 | 3 | 0 |
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

每一行是一个失败用例，共 121 行；分类不改变通过或失败的结果。“已知缺陷”包含已确认的不一致，其中综合信贷链的直接根因尚未完全定位，已在原因里注明。

| 套件 / 测试文件 | case ID | 分类 | 原因 |
| --- | --- | --- | --- |
| 0004-lending/0004-lending-test-01.xml | `001` | 已知缺陷 | 综合信贷决策链给出 DECLINE 而非 ACCEPT；直接根因尚未完全定位，保留为已知结果错误。 |
| 0013-sort/0013-sort-test-01.xml | `001` | 已知缺陷 | 字符串比较/排序未达到 TCK 要求的字典序，列表排序结果按长度分组。 |
| 0020-vacation-days/0020-vacation-days-test-01.xml | `001` | 已知缺陷 | 休假天数决策链返回 null 而非数字；表调用与传播路径的直接根因待定位。 |
| 0020-vacation-days/0020-vacation-days-test-01.xml | `002` | 已知缺陷 | 休假天数决策链返回 null 而非数字；表调用与传播路径的直接根因待定位。 |
| 0020-vacation-days/0020-vacation-days-test-01.xml | `003` | 已知缺陷 | 休假天数决策链返回 null 而非数字；表调用与传播路径的直接根因待定位。 |
| 0020-vacation-days/0020-vacation-days-test-01.xml | `004` | 已知缺陷 | 休假天数决策链返回 null 而非数字；表调用与传播路径的直接根因待定位。 |
| 0020-vacation-days/0020-vacation-days-test-01.xml | `005` | 已知缺陷 | 休假天数决策链返回 null 而非数字；表调用与传播路径的直接根因待定位。 |
| 0021-singleton-list/0021-singleton-list-test-01.xml | `001` | 已知缺陷 | 字符串函数调用链没有完成 singleton-list 参数适配，结果为 null 而非 BOB。 |
| 0036-dt-variable-input/0036-dt-variable-input-test-01.xml | `_20445ee0-744d-4488-a90e-136701510871` | 已知缺陷 | 决策表 inputVariable 与布尔 unary test 的作用域/匹配行为不正确。 |
| 0036-dt-variable-input/0036-dt-variable-input-test-01.xml | `_58109f16-2e9b-496e-bfff-5f0adbfa0279` | 已知缺陷 | 决策表 inputVariable 与布尔 unary test 的作用域/匹配行为不正确。 |
| 0057-feel-context/0057-feel-context-test-01.xml | `008` | 已知缺陷 | 重复 context 键当前抛 E_DUPLICATE，与该用例期望的 context 行为不一致；重复键策略待进一步规范核对。 |
| 0058-feel-number-function/0058-feel-number-function-test-01.xml | `009` | 已知缺陷 | grouping separator 与 decimal separator 相同仍被接受，应为 null/错误。 |
| 0058-feel-number-function/0058-feel-number-function-test-01.xml | `014` | 已知缺陷 | decimal sep/grouping sep 命名拼写没有被识别，编译阶段报错。 |
| 0067-feel-split-function/0067-feel-split-function-test-01.xml | `001` | 已知缺陷 | split 将分隔符当作普通文本，未按正则分隔符拆分。 |
| 0068-feel-equality/0068-feel-equality-test-01.xml | `datetime_003_a` | 规范与 TCK 存在差异 | TCK 描述要求忽略毫秒并判相等；实现保留小数秒，返回 false。DMN 1.5 §10.3.2.3.4/.6 的 valuet/valuedt 单射与表 66 的 decimal second 语义支持保留精度；需向上游核对该旧期望，当前仍计失败。 |
| 0068-feel-equality/0068-feel-equality-test-01.xml | `range_010` | 已知缺陷 | 单端比较 range 与双端 range 的相等性规则不正确。 |
| 0068-feel-equality/0068-feel-equality-test-01.xml | `time_005` | 规范与 TCK 存在差异 | TCK 描述要求忽略毫秒并判相等；实现保留小数秒，返回 false。DMN 1.5 §10.3.2.3.4/.6 的 valuet/valuedt 单射与表 66 的 decimal second 语义支持保留精度；需向上游核对该旧期望，当前仍计失败。 |
| 0069-feel-list/0069-feel-list-test-01.xml | `026` | 已知缺陷 | item 字段被注入的整个 item context 遮蔽，导致 context 与 number 比较。 |
| 0069-feel-list/0069-feel-list-test-01.xml | `031` | 已知缺陷 | filter 在逐项缺失字段探测时抛 E_NAME，没有产生空集/过滤剩余合法项。 |
| 0069-feel-list/0069-feel-list-test-01.xml | `032` | 已知缺陷 | filter 在逐项缺失字段探测时抛 E_NAME，没有产生空集/过滤剩余合法项。 |
| 0070-feel-instance-of/0070-feel-instance-of-test-01.xml | `context_019` | 已知缺陷 | 结构化 context 类型的 conforms-to 检查拒绝了该合法值。 |
| 0072-feel-in/0072-feel-in-test-01.xml | `list_001` | 已知缺陷 | 嵌套 list 的 membership/整体 list 相等适配不完整。 |
| 0072-feel-in/0072-feel-in-test-01.xml | `list_011_a` | 已知缺陷 | 嵌套 list 的 membership/整体 list 相等适配不完整。 |
| 0075-feel-exponent/0075-feel-exponent-test-01.xml | `decision_001` | 已知缺陷 | 幂运算解析当前右结合；3 ** 4 ** 5 未按 TCK 的左结合结果求值。 |
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
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decisionService_001` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decisionService_002_b` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decisionService_002_c` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decision_005` | 已知缺陷 | 结构化字段缺失被补成 null 后接受，与该声明类型要求的错误/null 不一致。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decision_bkm_002` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decision_bkm_003` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decision_bkm_004_a` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decision_bkm_005` | 已知缺陷 | literalExpression 的 number typeRef 未应用于 BKM 返回值；输出 [10] 未适配为 10。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decision_bkm_005_a` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `decision_context_03` | 已知缺陷 | 结构化字段缺失被补成 null 后接受，与该声明类型要求的错误/null 不一致。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `fd_002` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0082-feel-coercion/0082-feel-coercion-test-01.xml | `invoke_001` | 已知缺陷 | 表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。 |
| 0083-feel-unicode/0083-feel-unicode-test-01.xml | `decision_006` | 已知缺陷 | 未加引号的 Unicode context 键无法被 lexer/parser 接受。 |
| 0083-feel-unicode/0083-feel-unicode-test-01.xml | `decision_007` | 已知缺陷 | 未加引号的 Unicode context 键无法被 lexer/parser 接受。 |
| 0084-feel-for-loops/0084-feel-for-loops-test-01.xml | `decision_019_a` | 已知缺陷 | 非法 range domain 或 range/list 迭代区分不正确：本应 null/错误，却返回列表。 |
| 0084-feel-for-loops/0084-feel-for-loops-test-01.xml | `decision_020_a` | 已知缺陷 | 非法 range domain 或 range/list 迭代区分不正确：本应 null/错误，却返回列表。 |
| 0084-feel-for-loops/0084-feel-for-loops-test-01.xml | `decision_021_a` | 已知缺陷 | 非法 range domain 或 range/list 迭代区分不正确：本应 null/错误，却返回列表。 |
| 0084-feel-for-loops/0084-feel-for-loops-test-01.xml | `decision_022_a` | 已知缺陷 | 非法 range domain 或 range/list 迭代区分不正确：本应 null/错误，却返回列表。 |
| 0084-feel-for-loops/0084-feel-for-loops-test-01.xml | `decision_025` | 已知缺陷 | 非法 range domain 或 range/list 迭代区分不正确：本应 null/错误，却返回列表。 |
| 0085-decision-services/0085-decision-services-test-01.xml | `011` | 已知缺陷 | 服务位置参数按 href 排序绑定，未按声明输入参数次序绑定。 |
| 0085-decision-services/0085-decision-services-test-01.xml | `013` | 已知缺陷 | 服务位置参数按 href 排序绑定，未按声明输入参数次序绑定。 |
| 0085-decision-services/0085-decision-services-test-01.xml | `014` | 已知缺陷 | 服务位置参数按 href 排序绑定，未按声明输入参数次序绑定。 |
| 0086-import/0086-import-test-01.xml | `test_001` | 未实现 | 跨文件 import 的名称解析和导入 ItemDefinition 注册未实现。 |
| 0086-import/0086-import-test-01.xml | `test_002` | 未实现 | 跨文件 import 的名称解析和导入 ItemDefinition 注册未实现。 |
| 0087-chapter-11-example/0087-chapter-11-example-test-01.xml | `001` | 已知缺陷 | 综合信贷示例的风险/路由决策结果错误；直接根因尚未完全定位，不能声称规范歧义。 |
| 0087-chapter-11-example/0087-chapter-11-example-test-01.xml | `002` | 已知缺陷 | 综合信贷示例的风险/路由决策结果错误；直接根因尚未完全定位，不能声称规范歧义。 |
| 0087-chapter-11-example/0087-chapter-11-example-test-01.xml | `003b` | 已知缺陷 | 综合信贷示例的风险/路由决策结果错误；直接根因尚未完全定位，不能声称规范歧义。 |
| 0087-chapter-11-example/0087-chapter-11-example-test-01.xml | `003c` | 已知缺陷 | 综合信贷示例的风险/路由决策结果错误；直接根因尚未完全定位，不能声称规范歧义。 |
| 0087-chapter-11-example/0087-chapter-11-example-test-01.xml | `004` | 已知缺陷 | 综合信贷示例的风险/路由决策结果错误；直接根因尚未完全定位，不能声称规范歧义。 |
| 0089-nested-inputdata-imports/0089-nested-inputdata-imports-test-01.xml | `001` | 未实现 | 嵌套导入的 InputData/href 解析未实现。 |
| 0091-local-hrefs/0091-local-hrefs-test-01.xml | `001` | 未实现 | 绝对 URI 形式的本地 href 未解析；当前只接受 #id。 |
| 0100-arithmetic/0100-arithmetic-test-01.xml | `exponent_lhs_number_exp_rhs_number_003` | 已知缺陷 | 幂运算解析当前右结合；3 ** 4 ** 5 未按 TCK 的左结合结果求值。 |
| 0100-arithmetic/0100-arithmetic-test-01.xml | `subtract_lhs_dateAndTime_minus_rhs_date_001` | 已知缺陷 | date 与 date-time 混合相减未拒绝不兼容类型。 |
| 0100-arithmetic/0100-arithmetic-test-01.xml | `subtract_lhs_date_minus_rhs_dateAndTime_001` | 已知缺陷 | date 与 date-time 混合相减未拒绝不兼容类型。 |
| 0100-arithmetic/0100-arithmetic-test-01.xml | `subtract_lhs_time_minus_rhs_time_005` | 覆盖边界 | time 只有 IANA 名称而没有日期，不能唯一计算 Melbourne 的 DST 偏移；显式拒绝该相减，不猜测参考日期。 |
| 0100-arithmetic/0100-arithmetic-test-01.xml | `subtract_lhs_time_minus_rhs_time_006` | 覆盖边界 | time 只有 IANA 名称而没有日期，不能唯一计算 Melbourne 的 DST 偏移；显式拒绝该相减，不猜测参考日期。 |
| 1103-feel-substring-function/1103-feel-substring-function-test-01.xml | `010_fbf9a89fde` | 已知缺陷 | 负 start position 配合 length 的截取终点计算错误。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `K2-MatchesFunc-1` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `K2-MatchesFunc-17` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `K2-MatchesFunc-5` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `K2-MatchesFunc-6` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch07` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch08` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch09` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch10` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1111-feel-matches-function/1111-feel-matches-function-test-01.xml | `caselessmatch11` | 已知缺陷 | Unicode 大小写折叠/字符类或 XPath 正则语法支持不完整；MoonBit 正则子集与目标语义不一致。 |
| 1115-feel-date-function/1115-feel-date-function-test-01.xml | `039_67a6eafa3f` | 已知缺陷 | 扩展年份带前导零的非法 date 字符串被接受。 |
| 1116-feel-time-function/1116-feel-time-function-test-01.xml | `046_7b80221ec1` | 已知缺陷 | 时区 offset 格式化丢失秒分量，不能保留 ±02:45:55。 |
| 1116-feel-time-function/1116-feel-time-function-test-01.xml | `047_33cd7b9b15` | 已知缺陷 | 时区 offset 格式化丢失秒分量，不能保留 ±02:45:55。 |
| 1116-feel-time-function/1116-feel-time-function-test-01.xml | `053_3d956966c0` | 已知缺陷 | time(date) 缺少 UTC 午夜转换。 |
| 1117-feel-date-and-time-function/1117-feel-date-and-time-function-test-01.xml | `067_35fef99b53` | 已知缺陷 | 扩展年份带前导零的非法 date-time 字符串被接受。 |
| 1130-feel-interval/1130-feel-interval-test-01.xml | `finished by` | 已知缺陷 | 同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。 |
| 1130-feel-interval/1130-feel-interval-test-01.xml | `finishes` | 已知缺陷 | 同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。 |
| 1130-feel-interval/1130-feel-interval-test-01.xml | `overlaps after` | 已知缺陷 | 同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。 |
| 1130-feel-interval/1130-feel-interval-test-01.xml | `overlaps before` | 已知缺陷 | 同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。 |
| 1130-feel-interval/1130-feel-interval-test-01.xml | `started by` | 已知缺陷 | 同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。 |
| 1130-feel-interval/1130-feel-interval-test-01.xml | `starts` | 已知缺陷 | 同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。 |
| 1131-feel-function-invocation/1131-feel-function-invocation-test-01.xml | `001` | 已知缺陷 | 不存在的函数当前抛 E_NAME，而该用例期望 FEEL null；未统一调用失败语义。 |
| 1146-feel-context-put-function/1146-feel-context-put-function-test-01.xml | `nested008` | 已知缺陷 | context put 对 key/keys 的命名重载校验未区分，接受了该用例要求拒绝的调用。 |
| 1148-feel-now-function/1148-feel-now-function-test-01.xml | `001` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1148-feel-now-function/1148-feel-now-function-test-01.xml | `002` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1149-feel-today-function/1149-feel-today-function-test-01.xml | `001` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1149-feel-today-function/1149-feel-today-function-test-01.xml | `002` | 驱动未提供时钟 | 库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。 |
| 1151-boxed-filter/1151-boxed-filter-test-01.xml | `004` | 已知缺陷 | boxed filter 的非布尔 predicate 抛错误，该用例要求 null/元素过滤行为。 |
| 1151-boxed-filter/1151-boxed-filter-test-01.xml | `005` | 已知缺陷 | boxed filter 的非布尔 predicate 抛错误，该用例要求 null/元素过滤行为。 |
| 1153-boxed-some/1153-boxed-some-test-01.xml | `005` | 已知缺陷 | boxed some 的标量 domain 或非布尔 body 处理与规范/TCK 要求不一致。 |
| 1153-boxed-some/1153-boxed-some-test-01.xml | `006` | 已知缺陷 | boxed some 的标量 domain 或非布尔 body 处理与规范/TCK 要求不一致。 |
| 1154-boxed-every/1154-boxed-every-test-01.xml | `005` | 已知缺陷 | boxed every 的标量 domain 或非布尔 body 处理与规范/TCK 要求不一致。 |
| 1154-boxed-every/1154-boxed-every-test-01.xml | `006` | 已知缺陷 | boxed every 的标量 domain 或非布尔 body 处理与规范/TCK 要求不一致。 |
| 1157-implicit-conversions/1157-implicit-conversions-test-01.xml | `002_a` | 已知缺陷 | 决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。 |
| 1157-implicit-conversions/1157-implicit-conversions-test-01.xml | `007` | 已知缺陷 | 决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。 |
| 1157-implicit-conversions/1157-implicit-conversions-test-01.xml | `008` | 已知缺陷 | 决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。 |
| 1157-implicit-conversions/1157-implicit-conversions-test-01.xml | `009` | 已知缺陷 | 决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。 |
| 1157-implicit-conversions/1157-implicit-conversions-test-01.xml | `010` | 已知缺陷 | 决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。 |
| 1157-implicit-conversions/1157-implicit-conversions-test-01.xml | `011` | 已知缺陷 | 决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。 |
| 1160-multiple-imports/1160-multiple-imports-test-01.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |
| 1160-multiple-imports/1160-multiple-imports-test-02.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |
| 1160-multiple-imports/1160-multiple-imports-test-03.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |
| 1160-multiple-imports/1160-multiple-imports-test-04.xml | `001` | 未实现 | 多文件导入、别名与命名空间隔离未实现。 |

# 时态算术边界与溢出核验

本次核验对应 R2 的 N1，并覆盖 `feel/types`、求值器和内置函数中的时态算术调用链。
日期范围为 -999999999..999999999 年；公开 Date/Time/Duration 记录应通过解析器或校验构造器创建，字段满足各类型的规范化约束。这里的溢出检查不等于完整 FEEL/DMN 合规证明。

| 排查项 | 原风险、修复或安全依据 | 回归证据 |
| --- | --- | --- |
| 日期月份加减 | 年、月、增量先以 Int64 计算；先约束可接受增量再相加，负数按 floor division 求年。转回 Int32 前检查 ±999999999，越界 E_DATE_RANGE，保留月末 clamp。 | 两端年份 P0M、±P1M 越界、Int64 极值增量、年零两侧、正负闰年/月末 |
| ordinal / weekday / ISO 周 | 年份减一、era 和乘积全部使用 Int64。合法日期 ordinal 为 [-365243219162,365241780471]；weekday 余数规范化至 [0,6]。day-of-year 最大 366；周号计算最多向前看一个年份，-1000000000 仍在 Int32 内；era 计算已是 Int64。 | 极端 ordinal 的独立常量、weekday=1/5、历法往返、week/day 范围；额外检查 Int32 年份极值的 ordinal 顺序 |
| epoch day → 日期 | `civil_from_days` 在加 epoch 偏移前限制天数，转回 Int32 前再次限制年份；BigInt 入口 `date_from_ordinal` 先检查完整日期域再窄化。 | Int64 两端、BigInt 巨大天数、日期上下界、年零闰日 |
| 日期加减 days-time duration | 天数与目标 ordinal 在 BigInt 中计算，再经受检入口；向上取整也保留 BigInt，避免 MAX_INT64 天再加一个部分日回绕。 | 最大天数加日期、MAX 天加 1 秒后减日期、日期加减一天越界 |
| 年月时长解析/规范化 | 累积月数使用 BigInt，规范化后先检查年字段容量。最大幅值为 2147483647 年 11 月（25769803775 月），超出 E_DURATION_RANGE。 | 20 亿年、进位 23 月、正负越界、大数解析 |
| 年月时长加减、乘除、比值 | `total_months` 改为 Int64；合法两个值相加/减的幅值不超过 51539607550，远小于 Int64 上限。缩放结果保留 BigInt，受检后才分解到 Int32 年/月；保留既有舍入规则。 | 20 亿年加减、正负乘数、除法/时长比值、超容量乘除/加法 |
| years and months duration(from,to) | 两个日期的年月先提升 Int64；合法日期跨度最多 23999999987 月，现有日分量修正规则不变；结果经受检年月时长构造。 | ±999999999 年日期之间的正负跨度及跨完整年份域的日期加法 |
| days-time 时长转换/加减/缩放 | 总纳秒与归一化进位使用 BigInt。days 字段为非负 Int64，最大幅值为 MAX_INT64 天加 23:59:59.999999999；窄化前检查 days 容量，超出 E_DURATION_RANGE。negate 只改变符号，不对整数取绝对值。 | 最大值格式化、反号往返、自减、加 1 纳秒、进位越界、负 Int64 极值、缩放/比值 |
| 日期/日期时间相减及比较 | 不再把日期或差值乘成 Int64 纳秒；核心使用 BigInt `epoch_nanos` 或本地日历纳秒。完整日期域的跨度可精确转为 days-time duration；既有混合类型语义缺陷没有据此宣称已修复。 | 完整日期/UTC 日期时间跨度、极端时刻比较/固定偏移相等、两个 Int64 可表示端点之差超过 Int64 |
| 旧 instant() 接口 | 保持 Int64 返回类型，转换前检查 [-2^63,2^63-1] 纳秒，超出 E_DATE_RANGE；需要完整日期域时使用新增 `epoch_nanos()` BigInt 接口。 | 两个精确端点、各越界 1 纳秒、999999999 年 |
| clock / offset / time modulo | 合法 Time 的纳秒数在 [0,86400000000000]，固定 offset 在 ±50400 秒。duration 转 offset 在 BigInt 中检查整秒和幅值再转 Int32。时钟加法先 BigInt，再模一天，余数窄化始终安全。 | 24:00、23:59:59.999999999、非法巨大 offset、最大 duration 的时钟回绕 |
| IANA epoch → 日期时间 | 原有 BigInt UTC 窗口检查保留，只有 [0,4133980800000000000) 纳秒会进入 Int64 秒转换；再加 offset 也远小于 Int64 上限。最终仍校验本地年份 1970–2100。未改变 tzdata 范围。 | 窗口两侧拒绝；现有 DST gap/overlap、南半球与纳秒边界回归 |
| decimal → 时间单位 | 目标 scale 先限制在 Decimal128 的 [-6111,6176]；scale 相减最大 12287，不会 Int32 回绕；中间乘除为 BigInt，进入具体时长前再校验容量。 | Int32 极端 scale 明确错误、纳秒 half-even 舍入 |

主要测试：`feel/types/calendar_bounds_test.mbt`、`duration_bounds_test.mbt`、`epoch_bounds_test.mbt`，以及根包 `temporal_arithmetic_test.mbt`。CLI 与 Web 另固定了 N1 的四个反例。

底层 `.mbti` 的相关变化：月份增量与 `DurationYM::total_months` 使用 Int64；日期/时长的受检转换、规范化和加减可抛 EngineError；新增 `date_from_ordinal`、`duration_ym_of_months`、`DateTime::epoch_nanos`。调用方应处理 E_DATE_RANGE / E_DURATION_RANGE。根包 JSON API 的签名未改变。

复现：

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon check --deny-warn --target native
moon test --target native
moon check --deny-warn --target wasm-gc
moon test --target wasm-gc
moon check --deny-warn --target js
moon test --target js
moon fmt --check
moon info
git diff --exit-code -- '*.mbti'
python3 scripts/test-cli.py
scripts/build-web.sh
node web/smoke.mjs
```

实测：三个后端各 242/242 测试、CLI 16 项、Web smoke 26 项；TCK L2 116/116、L3 3170/3291。原始 TCK 与逐例失败分类见 `evidence/`；未修改 TCK 比较器、容差、用例或跳过规则。

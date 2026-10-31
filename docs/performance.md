# 后端性能（第 3a 阶段）

本机 macOS，MoonBit 0.1.20261028，native release。单次测量，不含编译时间；
不是跨机器性能承诺。计时使用 core/bench 单调时钟，单位由微秒换算为毫秒。

| 工作量 | 优化前 ms | 优化后 ms |
| --- | ---: | ---: |
| 预编译 FEEL，复用已解码 context，10000 次 | 21.468291 | 10.242500 |
| 每次解析同一 FEEL，复用已解码 context，10000 次 | 2928.643542 | 234.665459 |
| 预解析 DMN，1000 规则 FIRST 表，匹配最后一条，10000 次 | 52550.278125 | 10915.398583 |

FEEL 输入为 `sum([amount, 0.1, 0.2]) * 2`，amount=12。
表测试每次检查结果为 999，包含 JSON 输入解码；不包含 XML 解析。
表模型只预解析 XML，目前规则内 FEEL 仍在每次求值时编译。
因此 FEEL 的 compiled 数字不等于已编译整张决策表的性能。

热点来自 FEEL 调用重复构造 builtin/参数词表，以及 has() 的无效参数数组分配。
改为模块内缓存，只向调用方返回副本；词表去重后减少 lexer 最长名称扫描次数。
没有添加跨请求可变求值缓存，context 和 clock 仍彼此隔离。

复现（在仓库根目录）：

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon run benchmarks --target native --release
```

优化前版本：`93f7e9b`，同一命令；优化后的源码见紧随其后的 perf 提交。
原始数字：`evidence/performance-before.txt`、`evidence/performance-after.txt`。
为避免切换有未提交修改的工作目录，比较版本时应使用独立副本。

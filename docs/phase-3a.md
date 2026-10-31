# 第 3a 阶段实测交付

1. STANDARD 指定统计命令：8483 行（含注释与 whitebox 文件）；排除 whitebox 后 8445 行。
   单元测试 198 个 test block，另有 9 项 CLI 进程级检查。测试快照人工指定期望，未使用实现输出刷新期望。
2. native、wasm-gc、js 的 check --deny-warn 和 test 全通过，每后端 198/198。
   fmt --check、moon info 和 .mbti diff 均通过。原始记录：evidence/validation-phase-3a.json。
3. 固定 TCK commit 1e349176：L2 116/116，L3 3162/3291（96.08%），129 失败，无跳过。
   两个 evidence 报告均重新执行；L2 与原报告一致。完整套件矩阵见 conformance.md。
4. 新增本地提交如下，最终 evidence 与收尾提交可用 git log c3dc2ec..HEAD 查看。

```
e8299a1 ci(tck): enforce full level 2 and 96 percent level 3 conformance
0a10455 docs(api): document public operations and narrow model implementation exports
dcb5ae1 test(cli): validate executable JSON errors and fixed clocks across platforms
8416e6a perf(feel): cache and deduplicate builtin lexical vocabulary
93f7e9b bench: measure 10000 evaluations and a 1000-rule decision table
f48aaf9 ci: use official platform installers and check all three backends
6cc15d4 feat(api): inject scoped clocks and expose CLI fixed-time evaluation
0e9ce6a fix(feel): correct builtin signatures, null semantics, intervals and typed adaptation
```

性能，native release，单次本机实测，单位 ms：

| 10000 次工作量 | 优化前 | 优化后 |
| --- | ---: | ---: |
| 预编译 FEEL | 21.468291 | 10.242500 |
| 每次解析 FEEL | 2928.643542 | 234.665459 |
| 1000 规则表，匹配最后规则 | 52550.278125 | 10915.398583 |

复现命令和测量边界见 performance.md。表模型预解析 XML，但表内 FEEL 尚未整体预编译。

剩余失败分类：

| 分类 | 数量 |
| --- | ---: |
| E_TCK_MISMATCH | 55 |
| E_TCK_EXPECTED_ERROR | 23 |
| E_UNSUPPORTED_SYNTAX | 17 |
| E_IMPORT_UNSUPPORTED | 6 |
| E_PARSE | 6 |
| E_TYPE | 4 |
| E_DMN_ITERATOR | 4 |
| E_BUILTIN_UNSUPPORTED | 4 |
| E_NAME | 3 |
| E_TYPE_UNSUPPORTED | 2 |
| E_NUMBER | 2 |
| E_DMN_FILTER | 2 |
| E_DUPLICATE | 1 |

5. 风险和未完成边界：
   - 尚有 55 个结果不匹配和 23 个期望报错却成功；不能视为完整 DMN 合规实现。
   - import、Java 外部函数未实现；Unicode 正则、部分区间/函数类型适应与盒式表达式仍有缺口。
   - now/today 必须注入 clock 或 CLI --now；TCK 驱动未提供时钟，4 个动态时间用例继续失败。
   - CI 已采用官方 Unix/PowerShell 安装脚本、Windows MSVC 初始化及 TCK 比率门槛；Linux/Windows 远端运行尚未验证。
   - 根 API 已在三后端调用；宿主 JavaScript 导出封装和 Web 页面未做。底层 API 不承诺稳定。
   - 性能为单机单次测量；不代表吞吐 SLA，暂未实现整模型 FEEL 编译缓存。
   - 未 push、创建远程库或 publish，未修改全局 Git 配置。

收尾：未移动或删除文件；源码、原始输入、构建缓存、测试证据及未知文件全部保留。
没有本任务启动的常驻服务或浏览器页。manifest 和操作日志位于 evidence/closeout/。
没有恢复映射或 Trash 目标，也没有据此声称释放磁盘空间。

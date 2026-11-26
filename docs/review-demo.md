# 评审快速演示

打开[线上 Playground](https://sundaysebasidian-byte.github.io/moondmn/)，选 **Loan**。在依赖图选择 **Verdict**，每次只按表改一个输入。观察结果和 Verdict 表里的高亮；行号从 1 开始。两轮之间重新选 Loan，或恢复刚才修改的字段。

| 情形 | 输入变化 | 预期结果 | Verdict 命中 |
| --- | --- | --- | --- |
| 通过 | 保持预填值：Credit Score 为 712，Employment 为 employed | Approve | 第 4 行 |
| 人工复核 | 仅把 Employment 改为 unemployed | Refer | 第 3 行 |
| 拒绝 | 恢复 Employment 为 employed，仅把 Credit Score 改为 579 | Decline | 第 1 行 |

候选源码的 Loan 演示还验证了 Employment 显式为空，或预填模型中的贷款额、期数、年收入非正时，均走第 5 行转人工，不产生报价；这些属于复审候选，验证时的线上版本仍未包含。线上的核对只使用上表三条已验证输入。

在 **Insurance** 示例选择 **Quote**，用预填数据可得 `premium: 1500`。若只想运行命令行，多文件例子的固定结果为 56：

```sh
moon run cmd/main --target native -- eval examples/imports/main.dmn \
  --decision Total --input examples/imports/input.json
```

线上剧本是页面已有的 Loan 模型，与源码验收中用来卡 1000／2500 阈值的模型不同。源码验收用 Node 运行页面的真实 JavaScript 引擎并检查值和行号；这不代替浏览器中对输入框操作的核验。

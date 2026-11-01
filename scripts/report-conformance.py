#!/usr/bin/env python3
"""Reconcile reports and the reviewed semantic inventory; never change TCK results."""
import collections
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
reports = {n: json.loads((root / f'evidence/tck-level-{n}.json').read_text()) for n in (2, 3)}
# These are reviewed semantic themes, not inferred excuses for counting a pass.
reasons = {
 '0004-lending': '综合信贷决策链给出 DECLINE 而非 ACCEPT；直接根因尚未完全定位，保留为已知结果错误。',
 '0013-sort': '字符串比较/排序未达到 TCK 要求的字典序，列表排序结果按长度分组。',
 '0020-vacation-days': '休假天数决策链返回 null 而非数字；表调用与传播路径的直接根因待定位。',
 '0021-singleton-list': '字符串函数调用链没有完成 singleton-list 参数适配，结果为 null 而非 BOB。',
 '0036-dt-variable-input': '决策表 inputVariable 与布尔 unary test 的作用域/匹配行为不正确。',
 '0057-feel-context': '重复 context 键当前抛 E_DUPLICATE，与该用例期望的 context 行为不一致；重复键策略待进一步规范核对。',
 '0058-feel-number-function': 'number 的分隔符合法性/参数拼写处理不完整。',
 '0067-feel-split-function': 'split 将分隔符当作普通文本，未按正则分隔符拆分。',
 '0068-feel-equality': '单端比较 range 与双端 range 的相等性规则不正确。',
 '0069-feel-list': '过滤器作用域没有完整处理 item 字段遮蔽与缺失字段。',
 '0070-feel-instance-of': '结构化 context 类型的 conforms-to 检查拒绝了该合法值。',
 '0072-feel-in': '嵌套 list 的 membership/整体 list 相等适配不完整。',
 '0075-feel-exponent': '幂运算解析当前右结合；3 ** 4 ** 5 未按 TCK 的左结合结果求值。',
 '0076-feel-external-java': 'Java/varargs 外部函数需 JVM 或宿主回调，当前未实现；不会因不支持而计为通过。',
 '0082-feel-coercion': '表达式/函数/服务声明类型校验与输出适配未完整执行，含缺失字段策略。',
 '0083-feel-unicode': '未加引号的 Unicode context 键无法被 lexer/parser 接受。',
 '0084-feel-for-loops': '非法 range domain 或 range/list 迭代区分不正确：本应 null/错误，却返回列表。',
 '0085-decision-services': '服务位置参数按 href 排序绑定，未按声明输入参数次序绑定。',
 '0086-import': '跨文件 import 的名称解析和导入 ItemDefinition 注册未实现。',
 '0087-chapter-11-example': '综合信贷示例的风险/路由决策结果错误；直接根因尚未完全定位，不能声称规范歧义。',
 '0089-nested-inputdata-imports': '嵌套导入的 InputData/href 解析未实现。',
 '0091-local-hrefs': '绝对 URI 形式的本地 href 需匹配模型 namespace。',
 '0100-arithmetic': 'date 与 date-time 混合相减未拒绝不兼容类型。',
 '1103-feel-substring-function': '负 start position 配合 length 的截取终点计算错误。',
 '1111-feel-matches-function': '剩余 Unicode Kelvin 大小写折叠、XPath 字符类相减与反向引用未实现；底层正则不覆盖这些语义。',
 '1115-feel-date-function': '扩展年份带前导零的非法 date 字符串被接受。',
 '1116-feel-time-function': 'time 构造器的 date 隐式转换或秒级 offset 格式不完整。',
 '1117-feel-date-and-time-function': '扩展年份带前导零的非法 date-time 字符串被接受。',
 '1130-feel-interval': '同端点、开闭边界的 starts/finishes/overlaps 关系仍有不正确分支。',
 '1131-feel-function-invocation': '不存在的函数当前抛 E_NAME，而该用例期望 FEEL null；未统一调用失败语义。',
 '1146-feel-context-put-function': 'context put 对 key/keys 的命名重载校验未区分，接受了该用例要求拒绝的调用。',
 '1148-feel-now-function': '库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。',
 '1149-feel-today-function': '库已支持注入 clock，但 TCK 驱动未注入时钟；不使用隐含系统时间。',
 '1151-boxed-filter': 'boxed filter 的非布尔 predicate 抛错误，该用例要求 null/元素过滤行为。',
 '1153-boxed-some': 'boxed some 的标量 domain 或非布尔 body 处理与规范/TCK 要求不一致。',
 '1154-boxed-every': 'boxed every 的标量 domain 或非布尔 body 处理与规范/TCK 要求不一致。',
 '1157-implicit-conversions': '决策服务/BKM/调用表达式的输出类型适配未完整贯通，包括 singleton 和 date 到 date-time。',
 '1160-multiple-imports': '多文件导入、别名与命名空间隔离未实现。',
}
rows = []
for case in reports[3]['cases']:
    if case['status'] == 'PASS':
        continue
    suite = Path(case['file']).parent.name
    assert suite in reasons, f'unclassified suite: {suite}'
    category, reason = '已知 bug', reasons[suite]
    if suite in ('0076-feel-external-java', '0086-import', '0089-nested-inputdata-imports', '0091-local-hrefs', '1160-multiple-imports'):
        category = '未实现特性'
    elif suite.startswith(('1148-', '1149-')):
        category = '驱动环境未提供'
    if suite == '0068-feel-equality' and case['id'] in ('time_005', 'datetime_003_a'):
        category = '规范/TCK 差异待确认'
        reason = 'TCK 描述要求忽略毫秒并判相等；实现保留小数秒，返回 false。DMN 1.5 §10.3.2.3.4/.6 的 valuet/valuedt 单射与表 66 的 decimal second 语义支持保留精度；需向上游核对该旧期望，当前仍计失败。'
    elif suite == '0100-arithmetic' and 'minus_rhs_time' in case['id']:
        category = '覆盖边界'
        reason = 'time 只有 IANA 名称而没有日期，不能唯一计算 Melbourne 的 DST 偏移；显式拒绝该相减，不猜测参考日期。'
    elif suite == '0100-arithmetic' and case['id'].startswith('exponent_'):
        reason = reasons['0075-feel-exponent']
    elif suite == '0068-feel-equality' and case['id'] == 'range_010':
        reason = '比较式 (=x) 被表示为双闭点区间，丢失一元测试与双端区间的类型区别；需扩展值表示和相等规则。'
    elif suite == '0058-feel-number-function':
        reason = ('grouping separator 与 decimal separator 相同仍被接受，应为 null/错误。' if case['id'] == '009' else 'decimal sep/grouping sep 命名拼写没有被识别，编译阶段报错。')
    elif suite == '0069-feel-list':
        reason = ('item 字段被注入的整个 item context 遮蔽，导致 context 与 number 比较。' if case['id'] == '026' else 'filter 在逐项缺失字段探测时抛 E_NAME，没有产生空集/过滤剩余合法项。')
    elif suite == '1116-feel-time-function':
        reason = ('time(date) 缺少 UTC 午夜转换。' if case['id'].startswith('053_') else '时区 offset 格式化丢失秒分量，不能保留 ±02:45:55。')
    elif suite == '0082-feel-coercion' and case['id'] in ('decision_005', 'decision_context_03'):
        reason = '结构化字段缺失被补成 null 后接受，与该声明类型要求的错误/null 不一致。'
    elif suite == '0082-feel-coercion' and case['id'] == 'decision_bkm_005':
        reason = 'literalExpression 的 number typeRef 未应用于 BKM 返回值；输出 [10] 未适配为 10。'
    rows.append({**case, 'suite': suite, 'category': category, 'reason': reason})
assert len(rows) == reports[3]['failed']
assert len({(r['file'], r['id']) for r in rows}) == len(rows)
counts = collections.Counter(r['category'] for r in rows)
(root / 'evidence/failure-classification.json').write_text(json.dumps({'total':len(rows), 'categories':dict(counts), 'cases':rows}, ensure_ascii=False, indent=2)+'\n')
path = root / 'docs/conformance.md'
text = path.read_text()
for level, report in reports.items():
    text = re.sub(rf'\| Level {level} \| \d+ \| \d+ \| \d+ \| [\d.]+% \|', f"| Level {level} | {report['total']} | {report['passed']} | {report['failed']} | {100*report['passed']/report['total']:.2f}% |", text)
start = text.index('| `E_TCK_MISMATCH`')
end = text.index('\n\n下表按引擎返回的状态码', start)
text = text[:start] + '\n'.join(f'| `{code}` | {count} |' for code,count in sorted(reports[3]['failures'].items(), key=lambda pair:-pair[1])) + text[end:]
for suite in {Path(c['file']).parent.name for c in reports[3]['cases']}:
    cases = [c for c in reports[3]['cases'] if Path(c['file']).parent.name == suite]
    passed = sum(c['status']=='PASS' for c in cases)
    text = re.sub(r'\| '+re.escape(suite)+r' \| \d+ \| \d+ \| \d+ \|',f'| {suite} | {len(cases)} | {passed} | {len(cases)-passed} |',text)
def cell(value): return value.replace('|','&#124;').replace('\n',' ').replace('<','&lt;').replace('>','&gt;')
total = reports[3]['total']
failed = len(rows)
by_category = collections.Counter(r['category'] for r in rows)
meaning = {
    '已知 bug': '范围内的行为不正确，是待修的缺陷',
    '未实现特性': '尚未实现或明确不做',
    '覆盖边界': '实现主动拒绝，不猜测',
    '规范/TCK 差异待确认': '实现依据规范文本，与 TCK 期望不一致；仍计为失败',
    '驱动环境未提供': 'TCK 驱动不提供时钟；API 与 CLI 注入时钟后可用',
}
names = {'已知 bug': '已知缺陷', '未实现特性': '未实现', '覆盖边界': '覆盖边界', '规范/TCK 差异待确认': '规范与 TCK 存在差异', '驱动环境未提供': '驱动未提供时钟'}
bugs = [r for r in rows if r['category'] == '已知 bug']
by_suite = collections.Counter(r['suite'] for r in bugs)
first_reason = {}
for r in bugs:
    first_reason.setdefault(r['suite'], r['reason'])
out_of_scope = by_category['未实现特性'] + by_category['驱动环境未提供']
summary = f"""## 结论

Level 2 为 116/116。Level 3 为 {reports[3]['passed']}/{total}（{100*reports[3]['passed']/total:.2f}%），剩余 {failed} 个失败，没有跳过，也没有被隐藏的用例。

这 {failed} 个失败里，{by_category['已知 bug']} 个（{100*by_category['已知 bug']/failed:.0f}%）是引擎自己的缺陷，{out_of_scope} 个属于范围外或测试环境。通过率不能理解为“剩下的都是范围外”。

| 分类 | 失败数 | 占失败比例 | 含义 |
| --- | ---: | ---: | --- |
""" + ''.join(f"| {names[c]} | {by_category[c]} | {100*by_category[c]/failed:.1f}% | {meaning[c]} |\n" for c in meaning) + f"""
未实现的 {by_category['未实现特性']} 个中，Java 外部函数 {sum(1 for r in rows if r['suite']=='0076-feel-external-java')} 个，DMN `import` {sum(1 for r in rows if r['category']=='未实现特性' and r['suite']!='0076-feel-external-java')} 个。

已知缺陷集中在下面这些套件（按失败数排序，只列前 10 个；全部明细见文末）：

| 套件 | 失败数 | 症状举例 |
| --- | ---: | --- |
""" + ''.join(f"| {suite} | {count} | {cell(first_reason[suite])} |\n" for suite, count in by_suite.most_common(10)) + f"""
数字的来源：

- 全部 {total} 个用例都真实执行；runner、数值比较容差和上游期望值都没有为了提高通过率而修改。
- 失败清单可机读：`evidence/failure-classification.json`，每行以测试文件路径加 case ID 唯一标识；逐例原始报告是 `evidence/tck-level-*.json`。
- 任何一个套件都可以用下文“复现”一节的命令单独重跑。
"""
text = re.sub(r'<!-- summary:start -->.*<!-- summary:end -->', lambda _: '<!-- summary:start -->\n' + summary + '<!-- summary:end -->', text, flags=re.S)
marker = '\n## 逐例明细'
text = text.split(marker)[0].rstrip() + '\n'
text += marker + '\n\n每一行是一个失败用例，共 ' + str(failed) + ' 行；分类不改变通过或失败的结果。“已知缺陷”包含已确认但尚未修复的不一致，原因逐项注明。\n\n'
text += '| 套件 / 测试文件 | case ID | 分类 | 原因 |\n| --- | --- | --- | --- |\n'
for row in sorted(rows,key=lambda r:(r['file'],r['id'])):
    label = row['suite'] + '/' + Path(row['file']).name
    text += f"| {cell(label)} | `{cell(row['id'])}` | {names[row['category']]} | {cell(row['reason'])} |\n"
path.write_text(text)
print(f"Level 3 {reports[3]['passed']}/{reports[3]['total']}; {len(rows)} failures classified",dict(counts))

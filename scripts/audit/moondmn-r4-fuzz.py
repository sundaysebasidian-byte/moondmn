#!/usr/bin/env python3
"""MoonDMN r4 robustness fuzzer.

Drives the native CLI (`main.exe feel|lint|eval`) with truncated / mutated FEEL
expressions and DMN XML, plus targeted stress inputs (deep nesting, huge tables).
A defect is: timeout (>10s), signal/abort, exit code not in {0,1}, or stdout that
is not a single JSON/FEEL line with "error" structure on failure.

usage: moondmn-r4-fuzz.py <main.exe> <seed-dir-with-.dmn> <out-dir> [n=500]
"""
import json, os, random, subprocess, sys, tempfile, time

EXE, SEEDS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
N = int(sys.argv[4]) if len(sys.argv) > 4 else 500
TIMEOUT = 10
random.seed(20261116)
os.makedirs(OUT, exist_ok=True)
tmp = tempfile.mkdtemp(prefix="dmnfz-", dir=OUT)

FEEL_SEEDS = [
    'sum([1, 2, 3]) * 2', 'if x > 3 then "a" else "b"', 'for i in 1..3 return i * 2',
    'some x in [1,2,3] satisfies x > 2', '{a: 1, b: {c: [1,2,3]}}.b.c[2]',
    '[1,2,3][item > 1]', 'date("2024-02-29") + duration("P1Y")',
    '@"10:10:10@Australia/Melbourne"', 'substring("abc", 2)', 'matches("abc", "^a.c$", "i")',
    'function(a, b) a + b', '(function(n) n * 2)(21)', 'x instance of number',
    '[1..10] = [1..10]', 'string join(["a","b"], ",")', 'decimal(1/3, 2)',
    'not(true)', '1 between 0 and 2', '"a" in ("a", "b")', 'list replace([1,2,3], 2, 4)',
    'date and time("2018-12-08T10:00:00@Asia/Shanghai")', 'years and months duration(date("2020-01-01"), date("2021-03-01"))',
    'sort([3,1,2], function(a,b) a < b)', 'context put({}, "a", 1)', '0.1 + 0.2 = 0.3',
]
TOKENS = list('()[]{}.,:;+-*/<>=!"@?') + ['..', '**', ' and ', ' or ', ' for ', ' in ',
          ' return ', ' if ', ' then ', ' else ', ' satisfies ', ' function', ' instance of ',
          'null', '1e9999', '-0', '9' * 60, '"\\u0000"', '"\\uD800"', 'é', '\U0001F600', '@"', '`']


def mutate(s: str) -> str:
    for _ in range(random.randint(1, 4)):
        op = random.random()
        if not s:
            s = random.choice(TOKENS)
        i = random.randrange(len(s) + 1)
        if op < 0.25:
            s = s[:i]                                    # truncate
        elif op < 0.5:
            s = s[:i] + random.choice(TOKENS) + s[i:]    # insert token
        elif op < 0.7 and len(s) > 1:
            j = random.randrange(len(s))
            s = s[:j] + s[j + 1:]                        # delete char
        elif op < 0.85:
            s = s + s                                    # duplicate
        else:
            j = random.randrange(len(s) + 1)
            s = s[:min(i, j)] + s[max(i, j):][::-1]      # reverse tail
    return s


def run(args, label, inp):
    t = time.time()
    try:
        p = subprocess.run([EXE] + args, capture_output=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return {"label": label, "kind": "HANG", "input": inp[:300], "secs": TIMEOUT}
    dt = round(time.time() - t, 2)
    out = p.stdout.decode("utf-8", "replace").strip()
    err = p.stderr.decode("utf-8", "replace").strip()
    if p.returncode < 0 or p.returncode not in (0, 1):
        return {"label": label, "kind": "CRASH", "rc": p.returncode, "input": inp[:300],
                "stderr": err[-300:], "stdout": out[-200:], "secs": dt}
    if p.returncode == 1:
        try:
            j = json.loads(out.splitlines()[-1])
            assert "error" in j
        except Exception:
            return {"label": label, "kind": "BAD_ERROR_OUTPUT", "input": inp[:300],
                    "stdout": out[-200:], "stderr": err[-300:], "secs": dt}
    return {"label": label, "kind": "OK", "rc": p.returncode, "secs": dt,
            "err": (json.loads(out.splitlines()[-1]).get("error") if p.returncode == 1 else None)}


def feel(expr, label):
    if len(expr.encode()) > 200_000:
        # argv would exceed ARG_MAX: embed as a DMN literal expression and use `eval`
        from xml.sax.saxutils import escape
        path = os.path.join(tmp, "big.dmn")
        with open(path, "w") as f:
            f.write('<definitions xmlns="https://www.omg.org/spec/DMN/20230324/MODEL/" name="b" namespace="n">'
                    f'<decision name="D" id="D"><variable name="D"/><literalExpression><text>{escape(expr)}'
                    '</text></literalExpression></decision></definitions>')
        inp = os.path.join(tmp, "empty.json")
        open(inp, "w").write("{}")
        return run(["eval", path, "--decision", "D", "--input", inp], label + "/viaxml", expr)
    r = run(["feel", expr, "--now", "2024-02-29T23:30:00-05:00"], label, expr)
    return r


def xml_case(xml, label):
    path = os.path.join(tmp, "m.dmn")
    with open(path, "w", encoding="utf-8", errors="surrogatepass") as f:
        f.write(xml)
    r = run(["lint", path], label + "/lint", xml)
    return r


results = []
# 1. FEEL mutation
for k in range(N // 2):
    results.append(feel(mutate(random.choice(FEEL_SEEDS)), f"feel-mut-{k}"))

# 2. XML mutation (truncation + byte-level edits) over all seed models
seeds = []
for root, _, files in os.walk(SEEDS):
    for fn in files:
        if fn.endswith(".dmn"):
            seeds.append(open(os.path.join(root, fn), encoding="utf-8").read())
seeds = [s for s in seeds if len(s) < 200_000] or ["<definitions/>"]
for k in range(N // 2):
    s = random.choice(seeds)
    if random.random() < 0.5:
        x = s[:random.randrange(len(s))]
    else:
        x = s
        for _ in range(random.randint(1, 6)):
            i = random.randrange(len(x))
            x = x[:i] + random.choice(['<', '>', '"', '&', '&#0;', '&#x110000;', '</', '/>',
                                       '<!--', ']]>', '<![CDATA[', '\x00', '﻿', '']) + x[i + 1:]
    results.append(xml_case(x, f"xml-mut-{k}"))

# 3. targeted stress
D = [100, 1000, 10000, 100000]
for d in D:
    results.append(feel("(" * d + "1" + ")" * d, f"deep-paren-{d}"))
    results.append(feel("[" * d + "]" * d, f"deep-list-{d}"))
    results.append(feel("-" * d + "1", f"deep-unary-{d}"))
    results.append(feel("not(" * d + "true" + ")" * d, f"deep-not-{d}"))
    results.append(feel("{a:" * d + "1" + "}" * d, f"deep-ctx-{d}"))
    results.append(feel("if true then " * d + "1" + " else 0" * d, f"deep-if-{d}"))
    results.append(feel("+".join(["1"] * d), f"long-sum-{d}"))
    results.append(feel("x" + ".a" * d, f"long-path-{d}"))
results.append(feel('for i in 1..1000000 return i', "big-range-1e6"))
results.append(feel('count(for i in 1..3000, j in 1..3000 return 1)', "big-product-9e6"))
results.append(feel('string length(' + '"' + 'a' * 500_000 + '")', "long-string-500KB"))
results.append(feel('decimal(1, 999999999)', "decimal-huge-scale"))
results.append(feel('10 ** 999999999', "pow-huge"))
results.append(feel('matches("' + 'a' * 30 + '!", "^(a+)+$")', "regex-redos"))
results.append(feel('duration("P999999999999999999Y")', "duration-huge"))
results.append(feel('date("999999999-01-01")', "date-huge-year"))

ns = 'xmlns="https://www.omg.org/spec/DMN/20230324/MODEL/"'
for d in [100, 1000, 10000, 50000]:
    results.append(xml_case(f'<definitions {ns} name="d" namespace="n">' + "<extensionElements>" * d
                            + "</extensionElements>" * d + "</definitions>", f"xml-deep-{d}"))


def table(rules):
    rs = "".join(f'<rule><inputEntry><text>{i}</text></inputEntry><outputEntry><text>"{i}"</text></outputEntry></rule>'
                 for i in range(rules))
    return (f'<definitions {ns} name="t" namespace="n"><inputData name="x" id="x"><variable name="x" typeRef="number"/></inputData>'
            f'<decision name="D" id="D"><variable name="D"/><informationRequirement><requiredInput href="#x"/></informationRequirement>'
            f'<decisionTable hitPolicy="FIRST"><input><inputExpression typeRef="number"><text>x</text></inputExpression></input>'
            f'<output name="o"/>{rs}</decisionTable></decision></definitions>')


for rules in [1000, 10000, 50000]:
    path = os.path.join(tmp, f"t{rules}.dmn")
    open(path, "w").write(table(rules))
    inp = os.path.join(tmp, "in.json")
    open(inp, "w").write(json.dumps({"x": rules - 1}))
    results.append(run(["eval", path, "--decision", "D", "--input", inp], f"big-table-{rules}/eval", f"<{rules} rules>"))
    results.append(run(["lint", path], f"big-table-{rules}/lint", f"<{rules} rules>"))

with open(os.path.join(OUT, "fuzz-results.jsonl"), "w") as f:
    for r in results:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
bad = [r for r in results if r["kind"] != "OK"]
slow = sorted((r for r in results if r["kind"] == "OK"), key=lambda r: -r["secs"])[:8]
print(f"total={len(results)} defects={len(bad)}")
for r in bad:
    print(json.dumps({k: (v[:120] if isinstance(v, str) else v) for k, v in r.items()}, ensure_ascii=False)[:300])
print("slowest:", [(r["label"], r["secs"], r.get("err")) for r in slow])

sys.exit(1 if bad else 0)

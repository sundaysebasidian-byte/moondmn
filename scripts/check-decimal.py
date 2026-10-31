#!/usr/bin/env python3
"""Compare FEEL arithmetic with Python's independently implemented decimal128 context."""
import decimal as d
import json
from pathlib import Path
import random
import subprocess

rng = random.Random(1439)
ctx = d.Context(prec=34, Emin=-6143, Emax=6144, rounding=d.ROUND_HALF_EVEN, clamp=1)
ctx.traps[d.Overflow] = False
ctx.traps[d.Underflow] = False
expressions, expected = [], []
for _ in range(120):
    left = f'{rng.choice([-1, 1]) * rng.randrange(1, 10**34)}e{rng.randrange(-6176, 6112)}'
    right = f'{rng.choice([-1, 1]) * rng.randrange(1, 10**34)}e{rng.randrange(-6176, 6112)}'
    op = rng.choice(['+', '-', '*', '/'])
    a, b = ctx.create_decimal(left), ctx.create_decimal(right)
    result = {'+': ctx.add, '-': ctx.subtract, '*': ctx.multiply, '/': ctx.divide}[op](a, b)
    expressions.append(f'({left}) {op} ({right})')
    expected.append(result if result.is_finite() else None)
process = subprocess.run(['moon', 'run', 'cmd/main', '--target', 'native', '--', 'feel', '[' + ','.join(expressions) + ']'], capture_output=True, text=True, check=True)
actual = json.loads(process.stdout, parse_float=d.Decimal, parse_int=d.Decimal)
assert len(actual) == len(expected)
for expression, want, got in zip(expressions, expected, actual):
    assert want == got, (expression, str(want), str(got))
Path('evidence/r1-decimal-oracle.json').write_text(json.dumps({'oracle':'Python decimal.Context', 'precision':34, 'Emin':-6143, 'Emax':6144, 'rounding':'ROUND_HALF_EVEN', 'clamp':1, 'seed':1439, 'cases':len(expected), 'passed':len(expected)}, indent=2)+'\n')
print(f'decimal128 oracle: {len(expected)} arithmetic cases passed')

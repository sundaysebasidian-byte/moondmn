#!/usr/bin/env python3
"""Generate direct XPath case variants from Unicode upper/lower mappings."""
import hashlib
from pathlib import Path
root = Path(__file__).resolve().parent.parent
paths = [root / 'scripts' / name for name in ('UnicodeData-17.0.0.txt', 'SpecialCasing-17.0.0.txt')]
lower, upper = {}, {}
for line in paths[0].read_text().splitlines():
    f = line.split(';')
    c = int(f[0], 16)
    lower[c] = (int(f[13], 16),) if f[13] else (c,)
    upper[c] = (int(f[12], 16),) if f[12] else (c,)
for line in paths[1].read_text().splitlines():
    f = line.split('#')[0].split(';')
    if len(f) >= 5 and not f[4].strip():
        c = int(f[0], 16)
        lower[c] = tuple(int(x, 16) for x in f[1].split())
        upper[c] = tuple(int(x, 16) for x in f[3].split())
groups = []
for mapping in (lower, upper):
    inverse = {}
    for c, value in mapping.items():
        inverse.setdefault(value, []).append(c)
    groups.append(inverse)
text = '// Generated from Unicode 17.0.0 UnicodeData.txt and unconditional SpecialCasing.txt.\n'
for path in paths:
    text += '// ' + path.name + ' SHA-256: ' + hashlib.sha256(path.read_bytes()).hexdigest() + '\n'
text += '///|\nlet xpath_variants : Map[Int, Array[Int]] = {\n'
for c in sorted(lower):
    variants = {c}
    for mapping, inverse in zip((lower, upper), groups):
        variants.update(inverse[mapping[c]])
    if len(variants) > 1:
        text += f'  {c}: {sorted(variants)},\n'
text += '}\n'
(root / 'feel/builtins/unicode_fold.mbt').write_text(text)

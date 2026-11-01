#!/usr/bin/env python3
"""Generate simple case equivalence tables from the bundled Unicode data."""
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parent.parent
data = (root / 'scripts/CaseFolding-17.0.0.txt').read_bytes()
fold = {}
for line in data.decode().splitlines():
    fields = line.split('#')[0].split(';')
    if len(fields) > 2 and fields[1].strip() in ('C', 'S'):
        fold[int(fields[0], 16)] = int(fields[2], 16)
groups = {}
for source, target in fold.items():
    groups.setdefault(target, [target]).append(source)
text = '// Generated from Unicode 17.0.0 CaseFolding.txt, statuses C/S only.\n'
text += '// Source SHA-256: ' + hashlib.sha256(data).hexdigest() + '\n'
text += '///|\nlet xpath_folds : Map[Int, Int] = {\n'
text += ''.join(f'  {a}: {b},\n' for a, b in fold.items()) + '}\n'
text += '///|\nlet xpath_variants : Map[Int, Array[Int]] = {\n'
text += ''.join(f'  {b}: {values},\n' for b, values in groups.items()) + '}\n'
(root / 'feel/builtins/unicode_fold.mbt').write_text(text)

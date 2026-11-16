#!/usr/bin/env python3
"""MoonDMN r4: compare a fresh TCK run with committed evidence and list failures.
usage: moondmn-r4-tck.py <fresh-level-3.json> <committed evidence/tck-level-3.json>"""
import json, sys, collections
fresh, orig = (json.load(open(p)) for p in sys.argv[1:3])
for name, d in (("fresh", fresh), ("committed", orig)):
    print(name, {k: d[k] for k in ("total", "passed", "failed", "skipped")})
key = lambda d: sorted((c["file"], c["id"], c["status"]) for c in d["cases"])
print("per-case identical:", key(fresh) == key(orig))
fails = [c for c in fresh["cases"] if c["status"] != "PASS"]
print(collections.Counter(c["status"] for c in fails))
for c in fails:
    print(c["file"].split("/")[-1], c["id"], c["status"], c["detail"][:90])

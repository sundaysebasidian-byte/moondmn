#!/usr/bin/env python3
"""Compare a downloaded release archive against the reviewed MoonDMN v0.4.0 tag.
Run in a source checkout: python3 verify-reviewed-package.py /path/to/0.4.0.zip
No archive extraction, installation, credentials or network calls.
"""
from collections import Counter
from hashlib import sha256
from pathlib import Path
from subprocess import check_output
from sys import argv
from zipfile import ZipFile

RELEASE = "f08568721835cc78e5b0f59b926615c029ca7a98"
ARCHIVE = "9682e0888b39b92493e887352606e28d9d73cc0186d2e27c7c1431bbb2d9f795"

def check(path):
    path = Path(path)
    digest = sha256(path.read_bytes()).hexdigest()
    if digest != ARCHIVE:
        raise SystemExit(f"Unexpected archive SHA-256: {digest}")
    tracked = check_output(["git","ls-tree","-rz","--name-only",RELEASE]).decode().split("\0")
    code = {p for p in tracked if p.endswith(".mbt") or p.endswith("/moon.pkg") or p in {"moon.pkg", "moon.mod"}}
    with ZipFile(path) as z:
        seen = Counter(z.namelist())
        for name in sorted(code):
            if seen[name] != 1:
                raise SystemExit(f"Expected exactly one archive entry: {name}")
            if check_output(["git", "show", RELEASE+":"+name]) != z.read(name):
                raise SystemExit(f"Archive/source mismatch: {name}")
    print(f"{len(code)} source and manifest files match commit {RELEASE}; archive {digest}")

if __name__ == "__main__":
    if len(argv) != 2:
        raise SystemExit("Usage: python3 verify-reviewed-package.py /path/to/0.4.0.zip")
    check(argv[1])

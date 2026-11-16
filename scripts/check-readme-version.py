#!/usr/bin/env python3
"""Keep the source-version row aligned with package metadata."""
import pathlib
import re
version = re.search(r'^version = "([^"]+)"', pathlib.Path("moon.mod").read_text(), re.M)[1]
assert re.search(r"\| 当前源码 \| " + re.escape(version) + r"[， |]", pathlib.Path("README.md").read_text())
print("README source version:", version)

#!/usr/bin/env python3
"""Exercise the executable boundary, exit status and JSON diagnostics."""
import json
import subprocess
import tempfile
from pathlib import Path


def run(*args, code=0):
    result = subprocess.run(
        ["moon", "run", "cmd/main", "--target", "native", "--", *args],
        text=True, capture_output=True,
    )
    assert result.returncode == code, (args, result.stdout, result.stderr)
    return json.loads(result.stdout)


assert run("feel", "0.1+0.2") == 0.3
assert run("feel", "today()", "--now", "2024-02-29T23:30:00-05:00") == "2024-02-29"
assert run("feel", "now()", "--now", "2024-02-29T23:30:00-05:00") == "2024-02-29T23:30:00-05:00"
assert run("feel", "1+", code=1)["error"] == "E_PARSE"
assert run("feel", "x", "--context", code=1)["error"] == "E_CLI_ARGUMENT"
assert run("feel", "now()", "--now", "invalid", code=1)["error"].startswith("E_")
assert run("unknown", "x", code=1)["error"] == "E_CLI_USAGE"
with tempfile.TemporaryDirectory() as directory:
    context = Path(directory) / "context.json"
    context.write_text('{"Applicant Age":21}', encoding="utf-8")
    assert run("feel", "Applicant Age + 1", "--context", str(context)) == 22
assert run("eval", "examples/eligibility.dmn", "--decision", "Eligible", "--input", "examples/input.json") is True
print("CLI integration: 9 checks passed")

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
with tempfile.TemporaryDirectory() as directory:
    model = Path(directory) / "date.dmn"
    inputs = Path(directory) / "input.json"
    ns = "https://www.omg.org/spec/DMN/20230324/MODEL/"
    model.write_text(f"<definitions xmlns='{ns}'><inputData id='x' name='x'><variable typeRef='date'/></inputData><decision id='d' name='d'><informationRequirement><requiredInput href='#x'/></informationRequirement><literalExpression><text>x + duration(\"P1D\")</text></literalExpression></decision></definitions>", encoding="utf-8")
    inputs.write_text('{"x":"2024-02-28"}', encoding="utf-8")
    assert run("eval", str(model), "--decision", "d", "--input", str(inputs)) == "2024-02-29"
    inputs.write_text('{"Applicant":{"Credit Score":720}}', encoding="utf-8")
    assert run("feel", "Applicant.Credit Score", "--context", str(inputs)) == 720
    model.write_text(f"<definitions xmlns='{ns}'><decision id='d' name='d'><conditional><if><literalExpression><text>false</text></literalExpression></if></conditional></decision></definitions>", encoding="utf-8")
    assert run("eval", str(model), "--decision", "d", "--input", str(inputs), code=1)["error"] == "E_DMN_SHAPE"
print("CLI integration: 12 checks passed")

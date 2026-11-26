#!/usr/bin/env python3
"""Verify exact pinned case identities and statuses in the two reviewer clock modes."""
import argparse
from collections import Counter
from pathlib import Path
from runpy import run_path

ROOT = Path(__file__).resolve().parents[1]
read_report = run_path(str(ROOT / "scripts/audit/moondmn-r4-tck.py"))["read"]
L3 = ".tck/TestCases/compliance-level-3"
ONLY_CLOCK = {
    (f"{L3}/{suite}/{suite}-test-01.xml", "001"): ("PASS", "E_BUILTIN_UNSUPPORTED")
    for suite in ("1148-feel-now-function", "1149-feel-today-function")
}


def transitions(before, after):
    if before.keys() != after.keys():
        raise ValueError("report case inventory differs from the pinned baseline")
    return {key: (status, after[key]) for key, status in before.items() if status != after[key]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report_dir", type=Path)
    args = parser.parse_args()
    try:
        for level, count, expected_clock_delta in ((2, 116, {}), (3, 3291, ONLY_CLOCK)):
            baseline = read_report(ROOT / f"evidence/tck-level-{level}.json")
            fixed = read_report(args.report_dir / f"tck-level-{level}.json")
            no_clock = read_report(args.report_dir / f"tck-noclock-{level}.json")
            changed = transitions(baseline, fixed)
            if len(baseline) != count or changed:
                raise ValueError(f"level {level}: pinned report changed: {len(changed)} case transitions")
            if transitions(fixed, no_clock) != expected_clock_delta:
                raise ValueError(f"level {level}: no-clock changes differ from exact clock-dependent cases")
            for mode, report in (("fixed clock", fixed), ("no clock", no_clock)):
                statuses = Counter(report.values())
                print(f"level {level}, {mode}: {statuses.pop('PASS')}/{count}; {dict(sorted(statuses.items()))}")
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()

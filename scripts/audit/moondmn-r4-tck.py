#!/usr/bin/env python3
"""Compare two complete reports for the same pinned TCK level. Improvements pass."""
import argparse
from collections import Counter
import json
from pathlib import Path


def read(path):
    report = json.loads(path.read_text())
    ids = {}
    for case in report["cases"]:
        key = (case["file"], case["id"])
        if key in ids:
            raise ValueError(f"{path}: duplicate case {key}")
        ids[key] = case["status"]
    counts = Counter(ids.values())
    passed = counts.pop("PASS", 0)
    if (not ids or report["skipped"] != 0 or report["empty_files"] != 0 or
        report["total"] != len(ids) or report["passed"] != passed or
        report["failed"] != len(ids) - passed or dict(counts) != report["failures"]):
        raise ValueError(f"{path}: case rows do not describe a complete report with these totals")
    return ids


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fresh", type=Path)
    parser.add_argument("committed", type=Path)
    args = parser.parse_args()
    try:
        actual, expected = read(args.fresh), read(args.committed)
        if actual.keys() != expected.keys():
            raise ValueError(f"case inventory changed: missing={len(expected.keys()-actual.keys())}, added={len(actual.keys()-expected.keys())}")
        regressed = [key for key, old in expected.items() if old == "PASS" and actual[key] != old]
        if regressed:
            raise ValueError(f"{len(regressed)} previously passing case(s) regressed: {regressed[:8]}")
    except (KeyError, ValueError, OSError) as error:
        parser.exit(1, f"{error}\n")
    print(f"{sum(s == 'PASS' for s in actual.values())}/{len(actual)} passed; no previously passing case lost")


if __name__ == "__main__":
    main()

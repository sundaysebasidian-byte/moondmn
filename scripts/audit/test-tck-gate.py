"""Contract for the release gate: pinned identities, actual counts, and no regressions."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / "scripts/audit/moondmn-r4-tck.py"

class TckGate(unittest.TestCase):
    def setUp(self):
        self.golden = ROOT / "evidence/tck-level-3.json"
        self.fresh = json.loads(self.golden.read_text())
        self.good = next(c for c in self.fresh["cases"] if c["status"] == "PASS")
        self.bad = next(c for c in self.fresh["cases"] if c["status"] != "PASS")

    def check(self, expected):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fresh.json"
            path.write_text(json.dumps(self.fresh))
            p = subprocess.run([sys.executable, str(GATE), str(path), str(self.golden)],
                               capture_output=True, text=True)
            self.assertEqual(p.returncode, expected, (p.stdout, p.stderr))

    def test_same_totals_can_hide_a_regression(self):
        self.good["status"], self.bad["status"] = self.bad["status"], self.good["status"]
        self.check(1)

    def test_duplicate_id_cannot_replace_a_missing_case(self):
        self.good["id"] = "new-case"
        self.check(1)
        self.good.update(next(c for c in self.fresh["cases"] if c is not self.good and c["status"]=="PASS"))
        self.check(1)

    def test_fabricated_counts_rejected(self):
        self.fresh["passed"] += 1
        self.check(1)

    def test_identical_or_improved_results_allowed(self):
        self.fresh["cases"].reverse()
        self.check(0)
        self.fresh["passed"] += 1
        self.fresh["failed"] -= 1
        self.fresh["failures"][self.bad["status"]] -= 1
        self.bad["status"] = "PASS"
        self.check(0)

if __name__ == "__main__":
    unittest.main()

"""Regenerate from copies of the pinned reports; the source tree remains untouched."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class Report(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        for rel in ["scripts/report-conformance.py", "evidence/tck-level-2.json", "evidence/tck-level-3.json", "docs/conformance.md"]:
            dest = self.root / rel
            dest.parent.mkdir(exist_ok=True)
            shutil.copyfile(ROOT / rel, dest)
        self.doc = self.root / "docs/conformance.md"

    def generate(self):
        return subprocess.run([sys.executable, str(self.root/"scripts/report-conformance.py")], capture_output=True, text=True)

    def test_manual_sections_and_pinned_reports_survive_repeated_generation(self):
        inputs = sorted((self.root/"evidence").glob("tck*.json"))
        originals = [f.read_bytes() for f in inputs]
        self.doc.write_text(self.doc.read_text() + "\n## Reviewer annotation\n\nKeep this exact text.\n")
        suffix = self.doc.read_text().split("## 0.2.2 审计修复",1)[1]
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.doc.read_text().endswith("## 0.2.2 审计修复" + suffix))
        once = self.doc.read_bytes()
        self.assertEqual(self.generate().returncode, 0)
        self.assertEqual(self.doc.read_bytes(), once)
        self.assertEqual([f.read_bytes() for f in inputs], originals)

if __name__ == "__main__":
    unittest.main()

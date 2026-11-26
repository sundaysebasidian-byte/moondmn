#!/usr/bin/env bash
# Focused, local reviewer checks. The full suites and pinned TCK are documented separately.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

for target in native wasm-gc js; do
  printf '\nApproval boundaries | %s\n' "$target"
  moon test --target "$target" ./review_acceptance_test.mbt
done

moon test --target native ./dmn/model/r101_23_boxed_function_kind_test.mbt ./external_test.mbt

printf '\nMulti-file console and explicit rejection paths\n'
python3 scripts/test-cli.py

printf '\nPlayground JavaScript entry point\n'
scripts/build-web.sh
node web/smoke.mjs

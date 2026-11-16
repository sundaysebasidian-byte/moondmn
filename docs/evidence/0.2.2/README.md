# 0.2.2 audit repair evidence (unreleased)

Base: `9d7adf5`, isolated `compat-0.2.2` worktree. No main-checkout edits were read or copied, no push/publish, no GitHub repository metadata changes. Baseline builds use `git archive 9d7adf5` under ignored `.baseline/`, not the dirty main working tree.

Toolchain: `MOON_HOME=/tmp/moon-new PATH=/tmp/moon-new/bin:$PATH`; moon 0.1.20261104, moonc v0.10.20. Local host macOS, Node v24.18.0. CI Node 22 and other operating systems were not emulated.

Reproduce executable workflow commands: `python3 docs/evidence/0.2.2/run-local.py`. Exact commands, exit statuses and individual logs: `workflow-results.json`, `step-01.log` through `step-21.log`. These are actual runs, not inferred passes.

Actual output:

```text
moon check --deny-warn --target all: Finished. moon: ran 48 tasks, now up to date
moon fmt --check: Finished. moon: ran 90 tasks, now up to date
native:  Total tests: 306, passed: 306, failed: 0.
wasm-gc: Total tests: 306, passed: 306, failed: 0.
js:      Total tests: 306, passed: 306, failed: 0.
wasm:    Total tests: 306, passed: 306, failed: 0.
CLI integration: 38 checks passed
37 passed
Level 2: 116/116 passed
Level 3: 3271/3291 passed
```

`moon info` was regenerated and committed; `moon info && git diff --exit-code -- '*.mbti'` passes after the interface commits. TCK pinned commit: `1e349176e5ae689d924a2a2c7a8df25c220d8b07`. Both TCK runs use `--now 2026-01-01T00:00:00Z`. `tck-delta.json` records exactly six improvements and no regressions. 0103 is 50/50, 0100 is 1087/1087, 1148 and 1149 each 2/2. Remaining 20 failures are 18 JVM cases and two fractional-second differences. No error whitelist or comparison tolerance was changed.

## Workflow step ledger

Local execution covers executable bodies, not GitHub-hosted actions or OS matrix certification. Duplicate workflow steps refer to the same local executable checks below.

| Workflow / step | Result |
| --- | --- |
| CI/check checkout@v4 | Isolated worktree created at the specified main commit; GitHub action not run locally |
| CI/check Install MoonBit Unix | Pinned toolchain verified; `moon update` exit 0 (step 02). Installer intentionally not run over the required toolchain |
| CI/check Install MoonBit Windows | Not executable on this macOS host; no Windows installation/PowerShell policy changes |
| CI/check Configure MSVC | Not executable on macOS |
| CI/check Toolchain version | Exit 0, step 01 |
| CI/check Format check | Exit 0, step 03 |
| CI/check Type check | `--target all` includes native, wasm-gc, js and wasm; exit 0, step 04 |
| CI/check Build | Exit 0, step 05 |
| CI/check Test native | Exit 0, step 06 |
| CI/check Test wasm-gc | Exit 0, step 07 |
| CI/check Test js | Exit 0, step 08 |
| CI/check Test wasm (added) | Exit 0, step 09 |
| CI/check README version (added) | Exit 0, step 10 |
| CI/check CLI integration | Exit 0, step 11 |
| CI/check Interface drift | `moon info` exit 0, step 12; subsequent `git diff --exit-code -- '*.mbti'` exit 0 |
| CI/check README quick starts: API demo | Exit 0, step 13 |
| CI/check README quick starts: feel | Exit 0, step 14; output 12 |
| CI/check README quick starts: lint | Exit 0, step 15 |
| CI/check README quick starts: eval | Exit 0, step 16; output true |
| CI/playground checkout@v4 | Same isolated base; hosted action not run |
| CI/playground Install MoonBit | Same pinned toolchain and successful update |
| CI/playground setup-node@v4 | Not run; installed Node 24 used, not CI Node 22 |
| CI/playground Build playground | Exit 0, step 17 |
| CI/playground Smoke test | Exit 0, step 18; 37 passed |
| CI/tck checkout@v4 | Same isolated base; hosted action not run |
| CI/tck Install MoonBit Unix | Same pinned toolchain and successful update |
| CI/tck Install MoonBit Windows | Conditional step skipped by Ubuntu job; not executed locally |
| CI/tck Fetch pinned TCK | Exit 0, step 19 |
| CI/tck Level 2 | Exit 0, step 20 |
| CI/tck Level 3 | Exit 0, step 21 |
| CI/tck Summarise | Assertions pass in run-local.py; exact counts printed above |
| CI/tck Upload reports | GitHub artifact service not invoked; JSON reports retained in Git |
| Pages checkout@v4 | Same isolated base; hosted action not run |
| Pages Install MoonBit | Same pinned toolchain and successful update |
| Pages setup-node@v4 | Not run; local Node 24 used |
| Pages Build playground | Exit 0, step 17 |
| Pages Smoke test | Exit 0, step 18 |
| Pages configure-pages@v5 | Not run: hosted Pages configuration |
| Pages upload-pages-artifact@v3 | Not run: hosted upload; local web/dist inspected by smoke tests |
| Pages deploy-pages@v4 | Not run: user prohibited publishing |

## Robustness and regression evidence

Tracked upstream audit scripts are in `scripts/audit/`. Seed is 20261116; TCK snapshot and example models supply the XML corpus. Depth checks now assert diagnostic and exit status; fuzz exits nonzero for defects. Source corpora are generated deterministically by the scripts; generated XML inputs are retained locally, while result JSONL is committed.

```sh
python3 scripts/audit/moondmn-r4-depth.py _build/native/debug/build/cmd/main/main.exe
python3 scripts/audit/moondmn-r4-fuzz.py _build/native/debug/build/cmd/main/main.exe .tck/TestCases/compliance-level-3 docs/evidence/0.2.2/fuzz
```

JS/wasm-gc use the same scripts with executable wrappers invoking `node _build/js/debug/build/cmd/main/main.js "$@"` and `/tmp/moon-new/bin/moonrun _build/wasm-gc/debug/build/cmd/main/main.wasm "$@"` respectively. Build those CLIs with `moon build --target js cmd/main` / `moon build --target wasm-gc cmd/main`.

Each backend: depth `checks=62 crashes=0 all=E_LIMIT`; fuzz `total=550 defects=0`. See depth*.log, fuzz*.log and fuzz*/fuzz-results.jsonl. Four-backend regressions cover 5,000-term chains, type/test recursion, caller-built 5,000-deep AST, accepted 128-term addition, nested output printers and XML limits. DMN 1.1 and 1.2 return E_DMN_NAMESPACE; 1.3–1.5 accept empty definitions.

Before-fix arity tests fail on native/js/wasm-gc against the archived base (`before-*.log`). `before-repros.json` records actual base errors for arity and Melbourne subtraction. S3's baseline missing `to_string` was also observed as compiler error 4015; the new method is covered by the four-backend regression. No claim that finite fuzzing proves crash freedom.

Walker inspection: parsing now bounds precedence loops, postfix chains, unary recursion, type recursion, unary tests and iteration bindings. Compiled AST validation checks all Expr/Test variants with a bounded walker. Public evaluation and unary matching validate caller-built trees; recursive evaluation has a second bound. Existing XML parsing is iterative with a 128-element stack limit; model/import/type walkers retain their existing bounds. Value text/JSON printers are exercised on nested parsed values; arbitrarily deep host-constructed Values remain the host's responsibility.

## Unperformed external actions

S6 topics and GitHub Release were not changed: this task forbids push/publish. The already-published mooncakes 0.2.1 README cannot be updated by a local-only 0.2.2 commit; the corrected README will travel with a future authorized package publication. No upstream TCK issue was posted; S4 is addressed by a short specification excerpt and exact sections in docs/conformance.md. No claim of Windows/Linux execution or hosted Pages deployment.

## Performance

Existing release benchmarks were built from the archived base and final source using the same pinned compiler. Full interleaved order A/B/B/A is in benchmarks-final-source.json (two rounds, no omitted raw samples). The first pair includes cold-start noise: compiled main 17.176 ms versus compat 30.478 ms; the warmed second pair is 15.025 ms versus 14.523 ms. Full 1,000-rule/10,000-evaluation table runs: main 14341.102 / 14579.693 ms, compat 13303.011 / 13273.166 ms.

To isolate the two short existing workloads from table warm-up, benchmarks-short.json has one warm-up pair plus seven interleaved pairs through the same unmodified executables using a PTY for line buffering. Each own process was terminated after its two timing lines; table data comes only from completed full runs. Warm median compiled: main 15.289 ms, compat 15.019 ms (-1.77%); parsed: main 257.357 ms, compat 247.244 ms (-3.93%). No sustained regression observed; this short, noisy local comparison does not guarantee identical timings on other hosts. Earlier iterations and their slower preliminary timings are retained as benchmarks*.json, not presented as final-source measurements.

Baseline depth failures were independently reproduced: native 10,000 terms exits -11, JS and wasm-gc 5,000 terms exit 1 with recursive evaluator stack traces (before-depth.json). Core dumps were disabled for these probes.

## Closeout

One verified regenerable cache moved to recoverable Trash: `.baseline/_build` → `/Users/sebasidian/.Trash/_build`, 273,434,535 logical bytes. Tree SHA-256 checked before and after; exact file fingerprints, source path, actual destination, regeneration commands and restore mapping are in closeout-manifest.json. Original baseline source/specification, current worktree/build, dependencies, TCK snapshot and all evidence are retained. No servers/browser tabs started. Own benchmark/fuzz processes completed or were terminated; no user service was stopped.

`df -k` available before 126,512,552 KiB; after 126,511,080 KiB (observed -1,472 KiB). Same-volume Trash movement does not demonstrate reclaimed space; attributable release is not claimed. Moved 1, blocked 0. Restore only when the original path is absent; do not overwrite new content. Operation output is closeout-operation.log.

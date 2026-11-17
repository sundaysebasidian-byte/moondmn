# Fractional-second equality audit (0.2.2, Unreleased)

Base: `3f0b070b24143c9c33fcad2be8c444bfa5c1ad4f`, branch `eco-r3`.
Toolchain: `MOON_HOME=/tmp/moon-new PATH=/tmp/moon-new/bin:$PATH`, moon 0.1.20261104, moonc v0.10.20. Local macOS only.

## Decision

No spec-conformant change was identified that makes these two pinned expectations true. Retain the engine and report both failures. This is a disagreement with the TCK's explicit whole-second equality assumption, not an observed parsing, formatting, rounding or arithmetic defect. It is also not established as a JVM artifact: these are ordinary FEEL literal comparisons, separate from the 18 Java external-function failures. No tolerance, whitelist, upstream fixture, interface or engine code changed; no new unit tests were needed for this evidence-only outcome.

## Exact cases

TCK commit: `1e349176e5ae689d924a2a2c7a8df25c220d8b07`; clock: `2026-01-01T00:00:00Z`.
Both cases are in `TestCases/compliance-level-3/0068-feel-equality/0068-feel-equality-test-01.xml`.
The model is the adjacent `0068-feel-equality.dmn`.

| Case ID | FEEL expression | Expected | Actual |
| --- | --- | --- | --- |
| `time_005` | `time("10:30:00.0001") = time("10:30:00.0002")` | `true` | `false` |
| `datetime_003_a` | `date and time("2018-12-08T00:00:00.0001") = date and time("2018-12-08T00:00:00.0000")` | `true` | `false` |

Pinned sources: [test expectations, lines 541-547 and 657-663](https://github.com/dmn-tck/tck/blob/1e349176e5ae689d924a2a2c7a8df25c220d8b07/TestCases/compliance-level-3/0068-feel-equality/0068-feel-equality-test-01.xml#L541), [model expressions, lines 600-607 and 728-735](https://github.com/dmn-tck/tck/blob/1e349176e5ae689d924a2a2c7a8df25c220d8b07/TestCases/compliance-level-3/0068-feel-equality/0068-feel-equality.dmn#L600).
The descriptions explicitly require different fractional seconds to compare equal. They call these milliseconds, but each pair is separated by 0.0001 seconds = 100 microseconds = 100,000 nanoseconds.

## Root cause and counterexamples

1. `feel/builtins/builtins.mbt` sends the string constructors to `parse_time` / `parse_datetime`. `feel/types/temporal.mbt::parse_fraction` scales the four fractional digits exactly to nanoseconds: 100,000 vs 200,000 for time, and 100,000 vs zero for date-time. No floating-point conversion or rounding is involved. The existing nine-digit storage limit does not affect these inputs.
2. `feel/eval/eval.mbt::binary` dispatches `=` to `equal_value`, then `Value::equals`. In `feel/types/value.mbt`, `time_equals` compares nanosecond totals; `datetime_equals` compares whole-second instants AND the nanosecond fields. Neither discards the fraction. These unzoned inputs have no DST/offset ambiguity.
3. `tck/tck.mbt::equal` compares the resulting Boolean values exactly. Its numeric 1e-8 tolerance is irrelevant: the values being compared are `false` and `true`.

[probes.json](probes.json) records 18 native CLI probes, their exact argv, exit status, expected stdout and actual stdout. All 18 agree. Parsing/printing and `.second` retain 0.0001; numeric and string time constructors agree; zero fractional digits normalize away; extra trailing zeros compare equal. Time and date-time ordering distinguish the values; their subtraction gives `PT0.0001S` and adding that duration reconstructs the later value. Fractional durations also compare distinctly.

Truncating in the parser would lose the observed `.second` and duration differences. Truncating only equality would declare unequal numeric time values equal while their ordering and subtraction still distinguish them. Either would change the value semantics below. Changing printing cannot change these Boolean results. This is evidence against a semantics-preserving fix, not a claim that forcing the TCK expectations is technically impossible.

## Specification check

[DMN 1.5, formal/24-01-01](https://www.omg.org/spec/DMN/1.5/PDF) was downloaded and the relevant sections and tables checked in its extracted text. Local source fingerprint SHA-256: `196c80d0f483446a6e616ba096be5d44be0f8d1820684f59a41c80bfefc52e0f` (retained under ignored `.reference/dmn-1.5.pdf`).

- Section 10.3.2.2 directs equality to the semantic mappings; section 10.3.2.15, table 53 (printed p.126), compares time and date-time by their values, referring to sections 10.3.2.3.4 and 10.3.2.3.6 respectively. The latter is date-time; .5 is date, correcting the older evidence's citation.
- Section 10.3.2.3.4 (p.108) defines a seconds-based, one-to-one `valuet` mapping for time. Section 10.3.2.3.6 defines `valuedt` only for date-times that have a UTC form (a UTC offset). The `datetime_003_a` inputs have no offset, so that mapping does not directly support this case. For these local date-times, the argument relies on table 66 (p.133): `second` is a decimal, unlike integer hour/minute fields. It provides no rule to truncate fractional seconds for equality.
- Section 10.3.2.3.7 and table 57 retain seconds-based duration values in subtraction. The observed nonzero differences are consistent with these rules.

These are our inferences from the normative text, not an upstream adjudication. [XML Schema Part 2 sections 3.2.7-3.2.8](https://www.w3.org/TR/xmlschema-2/#time), referenced by DMN's time datatype, also support fractional seconds. [Java 11 LocalTime documentation](https://docs.oracle.com/en/java/javase/11/docs/api/java.base/java/time/LocalTime.html) specifies nanosecond precision, so whole-second equality is not an inherent Java time limitation. No Java runtime comparison or historical provenance investigation was performed; which upstream engine introduced this expectation remains unverified. No upstream issue was filed.

## Reproduction and validation

Fetch/verify the clean pinned corpus with `bash scripts/fetch-tck.sh`; dependencies with `moon update`. Both exited 0. Use the committed baseline linked below. The after-run and L2 reports use the documented native command and clock, with only the JSON destinations changed to retain separate audit evidence:

```sh
moon run cmd/main --target native -- tck .tck/TestCases/compliance-level-3 --now 2026-01-01T00:00:00Z --json docs/evidence/0.2.2/fractional-seconds/tck-level-3-after.json
moon run cmd/main --target native -- tck .tck/TestCases/compliance-level-2 --now 2026-01-01T00:00:00Z --json docs/evidence/0.2.2/fractional-seconds/tck-level-2.json
```

The original before-run and both commands above exited 0. Before and after L3: 3271/3291 passed, 20 failed, zero skipped (18 `E_EXTERNAL_UNBOUND`, two `E_TCK_MISMATCH`). L2: 116/116, zero failures/skips. [tck-delta.json](tck-delta.json) compares every file/ID/status: 0 improvements, 0 regressions, 0 added/removed cases, 3291 unchanged. The baseline is the previously committed [evidence/tck-level-3.json](../../../../evidence/tck-level-3.json) at `3f0b070b24143c9c33fcad2be8c444bfa5c1ad4f`; the fresh before-run was byte-identical to it (SHA-256 `3d5edb5c7bbd4ced4db9e91ab37bb280d8f2e4d485c644b3af1525725e6aba47`). The delta uses that committed report directly; only the after-run report is retained here.

[validation.txt](validation.txt) records the successful sequential commands:

```sh
moon fmt
moon check --deny-warn --target all
moon test --target native
moon test --target wasm-gc
moon test --target js
moon test --target wasm
moon info
git diff --exit-code -- '*.mbti'
python3 scripts/check-readme-version.py
```

All exited 0; each target has 306 total, 306 passed, 0 failed. README source version is 0.2.2. Existing test counts and TCK totals therefore remain unchanged. No Windows/Linux runtime, hosted CI or non-native full TCK execution was verified in this audit.

## Closeout

See [closeout-manifest.json](closeout-manifest.json). No cleanup candidates or Trash movements; no server/browser was started, and all task child processes exited. Current source/build, dependencies, pinned TCK, specification input and evidence are retained for reproduction. No old checkout was removed; complete remote backups were not audited and are not assumed. No space reclamation is claimed.

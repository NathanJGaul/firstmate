---
detected_at: 6f0f1399
ecosystems: [bash]
default: bash
stacks:
  bash:
    cwd: .
    runner: bin/fm-test-run.sh
    single: null
    file: 'bin/fm-test-run.sh {file}'
    suite: 'bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh'
    watch: null
    coverage: null
    mutation: null
    acceptance: null
    property: null
    approval: null
    contract: null
    test_glob: 'tests/*.test.sh'
    exemplar:
      unit: tests/fm-calm-claude-mod.test.sh
      acceptance: null
    helpers:
      - tests/lib.sh
verified: [file, suite]
suite_baseline: green
suite_seconds: 2
---

# TDD Stack Profile

## Conventions to match

- Behavior tests are self-contained executable Bash scripts named `tests/<subject>.test.sh` and are run through `bin/fm-test-run.sh` rather than directly chaining scripts.
- Tests source `tests/lib.sh` for `ROOT`, `pass`, `fail`, temporary roots, cleanup, fixture isolation, and shared assertions.
- TypeScript helpers are exercised through a temporary Node or Bun module launched by the Bash test; assertions are explicit state or output checks, not source-byte snapshots.
- The Calm Claude portable test at `tests/fm-calm-claude-mod.test.sh` is the unit/contract exemplar for pure TypeScript policy and sprite behavior.
- No acceptance or end-to-end runner is installed for OMP in this repository; OMP runtime smoke evidence is maintained separately in `docs/verification/runtime-backends.md`.

## Notes and constraints

- `bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh` ran successfully on 2026-10-06 with one selected script, zero failures, and 1.652 seconds for the script.
- The repository-wide `bin/fm-test-run.sh --all` baseline was started but exceeded the 3600-second command bound before producing a final summary; the full regression is not a viable per-cycle suite command and remains a validation limitation.
- `bin/fm-test-run.sh --check-coverage` was attempted and exited 1 with `comm: file 2 is not in sorted order`; coverage partition verification is unmeasured for this feature.
- There is no verified single-test-by-name selector for the Bash scripts; the loop runs one complete test file per cycle and records that limitation.
- Coverage, mutation testing, property-based testing, watch mode, approval snapshots, and a dedicated OMP acceptance runner are unavailable or unverified and are explicitly null above.
- The generated `.specify/memory/constitution.md` remains the Spec-Kit placeholder; the standard TDD constitution wording was not applied because it requires explicit project approval.

## Verification commands

- Focused file: `bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh`
- Feature suite: `bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh`
- Single test by name: `null` - Bash test files do not expose a verified selector.
- Coverage: `null` - `bin/fm-test-run.sh --check-coverage` failed before producing coverage evidence.
- Mutation: `null` - no mutation tool is present in the repository or lockfiles.

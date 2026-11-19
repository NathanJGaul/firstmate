# Tasks: Code Mode Guard Fixes

**Tests**: Required first. Each behavior test is seen failing for the right reason before its implementation, recorded in `tdd/cycle-log.md`.
Tests extend `tests/fm-cd-pretool-check.test.sh`; run with `bin/fm-test-run.sh tests/fm-cd-pretool-check.test.sh`.

- [X] T001 Baseline: run `tests/fm-cd-pretool-check.test.sh` and `tests/fm-turnend-guard.test.sh`, record in `tdd/cycle-log.md`.
- [X] T002 [A1,A2] Add the PreToolUse hook-config and launch-failure cases.
- [X] T003 [A3,B1] Add the deny-text cases (Code Mode `.cwd()` shape and a plain deny).
- [X] T004 Add `"onFailure": "continue"` to the three hooks.
- [X] T005 Extend the `persistent-cd` reason.
- [X] T006 Update `docs/cd-guard.md`, the Claude adapter reference, `docs/turnend-guard.md`, and `docs/verification/supervision.md`.
- [X] T007 `/speckit.tdd.verify` with mutants; `/speckit.implement`, `/speckit.checklist`, `/speckit.analyze`, `/speckit.converge`.
- [X] T008 `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, the changed suites.

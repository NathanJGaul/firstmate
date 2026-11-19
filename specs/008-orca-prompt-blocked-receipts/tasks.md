# Tasks: Orca Prompt-Blocked Receipts

**Tests**: Required first. Each behavior test is seen failing for the right reason before its implementation, recorded in `tdd/cycle-log.md`.
Tests extend `tests/fm-backend-orca.test.sh`, `tests/fm-task-inbox.test.sh`, and `tests/fm-backend-orca-smoke.test.sh`; run with `bin/fm-test-run.sh <file>`.

- [X] T001 Baseline: run the two unit suites, record in `tdd/cycle-log.md`.
- [X] T002 [U1,U2,U3,U4] Add the receipt-class, blocked-send, replay-blocked, and hook-less cases to `tests/fm-backend-orca.test.sh`.
- [X] T003 [A1] Add the typed `fm-send` blocked case.
- [X] T004 [A2] Add the ring cases to `tests/fm-task-inbox.test.sh`.
- [X] T005 Implement the class, the send verdict, and the ring mapping.
- [X] T006 Update headers and docs.
- [X] T007 Add the lab step to `tests/fm-backend-orca-smoke.test.sh`, run it in its isolated lab, and record the dated shapes in `docs/verification/runtime-backends.md`.
- [X] T008 `/speckit.tdd.verify` with mutants; `/speckit.implement`, `/speckit.checklist`, `/speckit.analyze`, `/speckit.converge`.
- [X] T009 `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, the changed suites.

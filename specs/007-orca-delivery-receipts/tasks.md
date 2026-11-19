# Tasks: Orca Delivery Receipts

**Input**: `specs/007-orca-delivery-receipts/` (spec.md, plan.md, research.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
Tests extend `tests/fm-backend-orca.test.sh`, `tests/fm-task-inbox.test.sh`, and `tests/fm-backend-orca-smoke.test.sh`; run each with `bin/fm-test-run.sh <file>`, and the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1`.

## Format: `[ID] [P?] [Behaviors] [Story] Description`

- **[A1,U1]**: the behavior ids from `tdd/test-list.md` that the task covers; `/speckit.tdd.run` ticks a behavioral task only from these markers
- **[Story]**: US1 receipt confirms, US2 retry by id, US3 gone terminal, US4 unchanged without receipts, US5 live proof

## Phase 1: Setup

- [X] T001 Run the baseline `bin/fm-test-run.sh tests/fm-backend-orca.test.sh`, `tests/fm-task-inbox.test.sh`, and `tests/fm-send-inbox.test.sh`, and record each result in `tdd/cycle-log.md` before any edit.
- [X] T002 Probe the real answers for a plain shell, a closed terminal, an exited shell, and a handle the runtime never issued in the lab (research only, `tests/fm-backend-orca-smoke.test.sh` step A12), and record the real error shape in `research.md`.

## Phase 2: Adapter receipts (US1, US2, US3, US4)

### Tests (write first, see them fail)

- [X] T003 [A6,U1,U13] [US4] Extend the fake `orca` in `tests/fm-backend-orca.test.sh` so `status` can list capabilities, then add the capability and unchanged-path cases.
- [X] T004 [U2] [US1] Add the receipt classification matrix.
- [X] T005 [U3,U4,U5,U6,U7] [US1,US2] Add the started, replayed, and exhausted-budget cases.
- [X] T006 [U8] [US2] Add the unsupported-receipt fallback case.
- [X] T007 [U9,U10] [US3] Add the gone and other-failure cases.
- [X] T008 [U11,U12] [US1] Add the wait-window and one-argument cases.
- [X] T009 [A1,A2,A3] [US1,US3] Add the `fm-send` typed, doorbell, and gone-terminal cases against the fake `orca`.
- [X] T010 [A4,A5] [US3] Add the ring cases to `tests/fm-task-inbox.test.sh`.

### Implementation

- [X] T011 [US4] Add `fm_backend_orca_has_capability` and `fm_backend_orca_receipt_class` to `bin/backends/orca.sh`; move the current body of `fm_backend_orca_send_text_submit` into `fm_backend_orca_send_text_submit_literal`.
- [X] T012 [US1,US2,US3] Make `fm_backend_orca_send_text_submit` choose the receipt path or the literal path and implement the receipt loop.
- [X] T013 [US3] Make `fm_task_inbox_ring` keep the verdict of a nonzero send and map `terminal-gone` to 3, and update its header.
- [X] T014 [US3] Confirm `bin/fm-send.sh`'s typed plane needs no change: the adapter's own stderr, which `fm-send` passes through, names the terminal and says nothing was delivered (proven by A3 and the lab).
- [X] T015 Update the `fm_backend_send_text_submit` header comment in `bin/fm-backend.sh` and the Orca adapter header.

## Phase 3: Live proof (US5)

- [X] T016 [US5] Turn A12 in `tests/fm-backend-orca-smoke.test.sh` into assertions on the observed shapes, and add the firstmate-level steps that send a typed text to the live task terminal and then to a closed one through `bin/fm-send.sh`.
- [X] T017 [US5] Run the lab and record the dated shapes in `docs/verification/runtime-backends.md`.
- [X] T018 Update `docs/orca-backend.md` where it describes the doorbell and the receipt options, then run `bin/fm-doc-audience-check.sh`.

## Phase 4: Lifecycle

- [X] T019 `/speckit.tdd.verify` with deliberate mutants for the capability gate, replay-by-id, the gone mapping, and the ring mapping.
- [X] T020 `/speckit.implement` remediation, `/speckit.checklist`, `/speckit.analyze`, and `/speckit.converge`.
- [X] T021 Run `bin/fm-lint.sh`, the changed suites, and the lab.

# Analysis: Orca Live Test Lab

Cross-artifact consistency check of `spec.md`, `plan.md`, `tasks.md`, and the implementation, run after the TDD loop and verification.

## Coverage

| Requirement | Task | Implementation | Test |
| ----------- | ---- | -------------- | ---- |
| FR-001 | T008 | `fm_live_gate opt-in FM_ORCA_LIVE_E2E` in the lane | A1 |
| FR-002, FR-003 | T002, T003 | `orca_lab_validate_data_dir`, `orca_lab_resolve` | A2, A3, U1-U7, U12 |
| FR-004, FR-005 | T006, T007 | `orca_lab_write_launcher`, runtime start in the lane | A5, U10; live run |
| FR-006, FR-007 | T004, T005 | `orca_lab_assert_own_runtime`, `orca_lab_signal`, `orca_lab_pid_owned` | A4, U8, U9 |
| FR-008 | T007 | `fm-test-` object names, exact-id removals, `orca_lab_leftovers` | A6, U11; live inventory |
| FR-009 | T008-T010 | `run_orca_level` assertions 1 to 10, assertion 11 recorded not run | live run |
| FR-010 | T011, T012 | `run_firstmate_level` | live run |
| FR-011 | T008 | `ok`, `observe`, `finding`, `notrun` vocabulary, zero-pass failure | live run |
| FR-012 | T002-T007 | guard test | A1-A6 |
| FR-013 | T013 | `bin/fm-test-run.sh` families and weight hints | A18 |
| FR-014 | T014, T015 | `docs/verification/runtime-backends.md` | `bin/fm-doc-audience-check.sh` |
| FR-015 | all | no `bin/` adapter file changed | diff |
| FR-016 | T016 | documented follow-up | none |

## Findings

| ID | Category | Severity | Location | Summary |
| -- | -------- | -------- | -------- | ------- |
| N1 | Inconsistency | LOW | `spec.md` FR-004, Overview | The spec says the lane refuses a caller-set data directory only when unsafe; in practice every Orca terminal exports `ORCA_USER_DATA_PATH` as the operator's directory, so a run from inside an Orca terminal must unset it. The refusal message and the verification record both say so. |
| N2 | Inconsistency | LOW | `plan.md` D2 | The plan says the repository's worktree base path is also set; the implementation relies on the runtime's own `HOME` instead and asserts every created path lies inside the lab, which proved sufficient and simpler. |
| N3 | Coverage gap | LOW | FR-009, FR-010 | The live assertions run only when opted in (finding 3 of `tdd/verification.md`). |
| N4 | Coverage gap | LOW | FR-016 | The nightly workflow is not written; a pinned runtime artifact, its license, and a mirror are unknown. |
| N5 | Ambiguity | LOW | `spec.md` US2.5 | "What Orca can and cannot prove about no agent" is reported as observations and a finding, not as a pass or fail, because the report asked what could be proven rather than that a specific proof exist. |

No CRITICAL or HIGH findings; no requirement lacks a task, and no task lacks a requirement.

## Scope check

No adapter behavior changed.
The findings that call for adapter changes (adopting the existing terminal from `terminal list`, reading the terminal's `processId`, Escape and Ctrl+U delivery, delivery receipts) are follow-ups listed in the pull request.

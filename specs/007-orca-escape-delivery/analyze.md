# Analysis: Orca Escape and Ctrl+U Delivery

Cross-artifact consistency check of `spec.md`, `plan.md`, `tasks.md`, and the implementation, run after the TDD loop and verification.

## Coverage

| Requirement | Task | Implementation | Test |
| ----------- | ---- | -------------- | ---- |
| FR-001, FR-004 | T004 | `fm_backend_orca_status_read` | U8, U9, U10 |
| FR-002, FR-003 | T004 | `fm_backend_orca_runtime_check` | U9, U10, U11 |
| FR-005, FR-006 | T005 | `fm_backend_orca_send_key` arms | U2, U3, U4, A1, A2, A4 |
| FR-007 | T005 | `fm_backend_orca_control_bytes_ready` | U5, U6, A5 |
| FR-008 | T005 | Enter and Ctrl+C arms untouched | U7, A3 |
| FR-009 | T007 | `fm_control_backend_supports_key` | U1 |
| FR-010 | T007 | no change to the classifier table | A6 |
| FR-011 | T009 | five documentation surfaces | read in review; `bin/fm-doc-audience-check.sh` |
| FR-012 | T008 | lab sections A5 and F | A7 |

## Findings

| ID | Category | Severity | Location | Summary |
| -- | -------- | -------- | -------- | ------- |
| N1 | Ambiguity | MEDIUM | `spec.md` Assumptions | Orca names no capability for control-byte passthrough. The gate uses `terminal.ordered-input.v1`, a proxy. The spec, research D3, the adapter comment, and the docs all say so, and a runtime that lacks it falls back to today's behavior. |
| N2 | Coverage gap | LOW | FR-011 | Documentation text has no executable test; covered by review and the documentation audience check. |
| N3 | Inconsistency | LOW | `docs/verification/runtime-backends.md` | The earlier lab entry still records Escape as refused and `passed=35`; it was reworded to say "before delivery landed", and the dated entry for this slice records the new run. |
| N4 | Behavior change | MEDIUM | `spec.md` Assumptions | The floor equals the one proven runtime, so the 1.4.116 macOS app recorded earlier is refused at spawn until updated or re-proven. Stated in the spec, the Orca docs, and the verification record. |

No CRITICAL or HIGH findings; no requirement lacks a task, and no task lacks a requirement.

## Scope check

Out-of-scope neighbours were left alone: startup-terminal adoption, delivery receipts, viewport capture, and agent-state proof for `exit` and `relaunch`.
The one unrelated change is the test runner's `comm` locale fix, made because `--check-coverage` failed on `main` under a UTF-8 locale; it is its own commit.

# Analysis: Orca Fleet Plumbing

Cross-artifact consistency check of `spec.md`, `plan.md`, `tasks.md`, and the implementation, run after the TDD loop and verification.

## Coverage

| Requirement | Task | Implementation | Test |
| ----------- | ---- | -------------- | ---- |
| FR-001, FR-002, FR-003, FR-004 | T005, T006 | `fm_backend_fleet_required_tools` (`bin/fm-backend.sh`), bootstrap loop | A1-A4, A6, U1 |
| FR-005 | T006 | bootstrap treehouse check over the union | A7 |
| FR-006 | T006 | default-first ordering | A5 |
| FR-007, FR-008 | T008 | `ORCA_FLOOR_NAMES` in `bin/fm-spawn.sh` | A8-A11 |
| FR-009 | T008 | `fm-spawn.sh` header, `docs/configuration.md` | read in review; no executable check |
| FR-010, FR-011, FR-013 | T012, T013 | `window_wake_name`, every `stale:` reason | A12, A13, U2-U4 |
| FR-012 | T013 | queue keys unchanged | A12, A13 |
| FR-014 | T012 | `window_to_task` fallback and Orca `window=fm-<id>` | A14, U5 |

## Findings

| ID | Category | Severity | Location | Summary |
| -- | -------- | -------- | -------- | ------- |
| N1 | Inconsistency | LOW | `spec.md` FR-010, FR-011 | The first draft said a handle "ends in `fm-<id>`"; a fixture with a tmux window `test:fm-chain-firstsight` for task `chain-first` showed the rule must be "last component starts with `fm-`". The spec, plan, header, and helper were updated together; no stale wording remains (grep for `ends in`). |
| N2 | Coverage gap | LOW | FR-009 | Documentation text has no executable test; covered by review and the documentation audience check. |
| N3 | Ambiguity | LOW | `spec.md` Assumptions | The Orca name list is the set observed on 1.4.261; a name a later Orca adds is not retained until added. Stated in the spec and in the `fm-spawn.sh` comment. |

No CRITICAL or HIGH findings; no requirement lacks a task, and no task lacks a requirement.

## Scope check

Out-of-scope neighbours were left alone: `CLAUDE_CODE_PLUGIN_DIRS` (injected by Orca without the prefix), the Orca CLI discovery slice, and the version gate.
`tests/fm-bootstrap.test.sh`'s herdr missing-CLI case was made hermetic because it failed on `main` on a host with a real `herdr`, as its own commit.

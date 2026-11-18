# Convergence: Orca Backend Leak Fixes

Assessed after the TDD loop, verification, implementation, checklist, and analysis, against the spec, plan, and tasks as the only source of intent.

## Result

One partial gap, appended as T036 in `tasks.md` Phase 8 and closed as behavior A11 (cycle 10 of the strict redo); no missing, contradicting, or unrequested work.

| ID | Gap type | Severity | Source | Evidence | Remaining work |
| -- | -------- | -------- | ------ | -------- | -------------- |
| F1 | partial | MEDIUM | FR-003, plan D4 | The adapter titles whichever terminal worktree creation returns, but no test asserts the rename for the `result.terminal` shape | T036 |

## Checked

- 9 functional requirements, 4 success criteria, 9 acceptance scenarios, 1 edge case, 6 plan design points, all satisfied in `bin/backends/orca.sh` and covered by `tests/fm-backend-orca.test.sh` except F1.
- The constitution is an unfilled template, so its checks were skipped.
- `bin/fm-spawn.sh` and `bin/fm-teardown.sh` are untouched, as the plan says.

## Merge readiness and risk

- Evidence: the final full run of the changed file passed (72 ok, 0 not ok) and so did the teardown endpoint-safety suite (27 ok); lint, the doc audience check, and the runner coverage guard (under `LC_ALL=C`) are clean; T036's test passes and its mutant is killed.
- Risk: no live Orca proof exists, so the single live terminal and the branch outcomes are proven against the fake only; an older Orca host that rejects `--delete-branch` would fail the release, which teardown reports as a refusal with records kept.
- The earlier test-after finding was resolved by the captain's chosen strict redo: `tdd/cycle-log.md` cycles 1 to 11 each record a red before the change, and `tdd/verification.md` passes.

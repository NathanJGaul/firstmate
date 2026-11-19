# Cycle Log: Orca Prompt-Blocked Receipts

Append only. Newest last.

## Baseline

- `tests/fm-backend-orca.test.sh` -> rc=0 (236 s) and `tests/fm-task-inbox.test.sh` -> rc=0 (325 s), run from an export of `HEAD` (`5766667f`) before any edit.
- full profile suite: not run here, left to CI.

Method notes:

- Neither suite has a per-test selector, so each red below was observed by running only the named function through a scratch copy of the test file whose call list was replaced, against the unchanged adapter and ring library; nothing in that wrapper is committed.
- Tests, implementation, and this log land in one commit.

## Cycle 1: a parked prompt is named (A1, U1, U2, U3)

- tests (new in `tests/fm-backend-orca.test.sh`, with fixtures `rc_blocked` and `rc_hookless`): `test_receipt_class_matrix` (extended), `test_receipt_blocked_prompt_is_prompt_blocked` (U2), `test_receipt_blocked_replay_is_prompt_blocked` (U3), `test_fm_send_typed_names_a_blocked_prompt` (A1)
- red against the unchanged adapter:
  - U1 `not ok - receipt class for a parked permission or trust prompt: expected 'blocked<TAB>agent_prompt_blocked', got 'failed<TAB>agent_prompt_blocked'`
  - U2 `not ok - a parked permission or trust prompt should report prompt-blocked, got 'send-failed'`
  - U3 `not ok - a replay refused by a parked prompt should report prompt-blocked, got 'send-failed'`
  - A1 `not ok - the error must say nothing was delivered (missing: 'nothing was delivered')`
- green: `fm_backend_orca_receipt_class` gains the `blocked` class and the receipt loop a `blocked)` case that prints `prompt-blocked`, exits 1, and writes the stderr message. All four pass.
- refactor: none.

## Cycle 2: the ring maps it to a failed ring (A2)

- test (new in `tests/fm-task-inbox.test.sh`): `test_ring_reports_a_blocked_orca_prompt_as_a_failed_ring`
- red: `not ok - the ring must name the blocked prompt on stderr, got: ` (the unchanged ring already returned 2 through the nonzero exit, but silently).
- green: `fm_task_inbox_ring` names the prompt on stderr and returns 2 for `prompt-blocked`, including when the send exited 0.
- refactor: none.

## Cycle 3: a hook-less accepted receipt (U4)

- test: `test_receipt_hookless_accepted_is_replayed_by_id`, plus the hook-less row in the class matrix.
- red: none by design. It is a characterization of the existing accepted path, so it was green before the change; its strength is shown by mutant M7 in `tdd/verification.md`.
- correction: the first fixture put the warning inside `prompt`, which is not the recorded shape (`result.warnings[]`); mutant M7 survived it, so the fixture was fixed to the recorded shape and M7 re-run and killed.

## Live proof

Step A12 in `tests/fm-backend-orca-smoke.test.sh` sends text plus Enter to a fake named claude that prints the workspace-trust dialog. Result on the 1.4.261 runtime: `agent_prompt_blocked`, nothing typed, and the adapter reported `prompt-blocked` with exit 1. Orca-level section: `passed=30 findings=4`, the four findings unrelated to this change.

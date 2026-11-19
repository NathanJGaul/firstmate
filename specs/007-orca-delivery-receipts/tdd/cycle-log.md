# Cycle Log: Orca Delivery Receipts

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` -> rc=0 (164 s)
- `bin/fm-test-run.sh tests/fm-send-inbox.test.sh` -> rc=0 (92 s)
- `bin/fm-test-run.sh tests/fm-task-inbox.test.sh` -> rc=0 (179 s)
- live lab, Orca-level section only (`env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1 FM_ORCA_LIVE_SECTIONS=orca tests/fm-backend-orca-smoke.test.sh`) -> `passed=23 findings=4`
- full profile suite: not run here, left to CI
- commit: `46987259`

Method notes:

- None of the touched suites has a per-test selector, so each red below was observed by running only the named function through a scratch copy that sources the same file with its call list replaced, against a copy of `bin/` holding the unchanged adapter and ring library from `HEAD`; nothing in that wrapper is committed.
- Tests, implementation, and this log land in one commit per cycle.
- Research step before any test: the lab's A12 step was first written as observation only, to read the real answer for a plain shell, a closed terminal, an exited shell, and a handle the runtime never issued.
  It is the live proof now (`research.md` records the observed shapes).

## Cycle 1: US1 to US4 the adapter's receipt path (A1-A3, A6, U1-U13)

- tests (new, in `tests/fm-backend-orca.test.sh`, whose fake `orca` now also lists capabilities, answers a status verbatim, answers a verb by name, and can print an answer together with a failing exit): `test_has_capability_reads_the_status_list` (U1), `test_receipt_class_matrix` (U2), `test_receipt_started_is_empty` (U3), `test_receipt_accepted_is_replayed_by_id` (U4), `test_receipt_exhausted_with_empty_composer_is_empty` (U5), `test_receipt_exhausted_with_pending_composer_retries_enter_only` (U6), `test_receipt_exhausted_with_unreadable_composer_is_pending` (U7), `test_receipt_unsupported_falls_back_to_the_composer` (U8), `test_receipt_gone_terminal_is_terminal_gone` (U9), `test_receipt_other_failures_stay_send_failed` (U10), `test_receipt_wait_window_is_tunable` (U11), `test_receipt_text_is_one_argument` (U12), `test_failed_status_read_selects_the_current_path` (U13), `test_fm_send_typed_uses_the_receipt_on_orca` (A1), `test_fm_send_doorbell_uses_the_receipt_on_orca` (A2), `test_fm_send_typed_names_a_gone_terminal` (A3), `test_fm_send_without_the_capability_is_unchanged` (A6)
- red against the unchanged adapter:
  - U1 `not ok - a status list naming terminal.prompt-delivery.v1 should report the capability, got rc=127`
  - U2 `not ok - receipt class for a started turn: expected 'started	req-1', got ''`
  - U3 `not ok - a started receipt should report empty, got 'unknown'`
  - U4 `not ok - a replay that proves the turn should report empty, got 'unknown'`
  - U5 `not ok - an accepted input that left the composer should report empty, got 'unknown'`
  - U6 `not ok - exactly one Enter-only retry expected, got 2`
  - U7 `not ok - input Orca accepted but the screen cannot confirm should report pending, got 'unknown'`
  - U8 `not ok - an unsupported receipt with an empty composer should report empty, got 'unknown'`
  - U9 `not ok - a closed or exited terminal should report terminal-gone, got 'send-failed'`
  - U10 `not ok - the runtime's message must reach stderr (missing: 'the runtime tripped')`
  - U11, U12 `not ok - got 'unknown'`
  - A1 `not ok - one receipt send expected, got 2`
  - A2 `not ok - the doorbell must request the receipt (missing: '--enter--wait-submit2')`
  - A3 `not ok - the error must say the terminal is gone (missing: 'is gone')`
  - U13 and A6 were green before the change: they are guards that pin "the current loop is unchanged when the capability is absent or unreadable", which the implementation must keep true.
    Their strength is shown by the mutants in `tdd/verification.md`.
- green: `bin/backends/orca.sh` gains `fm_backend_orca_has_capability`, `fm_backend_orca_receipt_class`, and the receipt loop, and `fm_backend_orca_send_text_submit` chooses between it and the unchanged literal loop (now `fm_backend_orca_send_text_literal`). Every test above passes.
- correction: the first draft of the send counting helper passed a `--`-prefixed pattern to `grep -F` without `-e`, which made U4 through U8 count nothing; the helper, not the adapter, was wrong, and it was fixed before the green run. The reds above were re-observed against the unchanged adapter with the corrected helper.
- refactor: none.

## Cycle 2: US3 the ring reads a gone terminal (A4, A5)

- tests (new, in `tests/fm-task-inbox.test.sh`, with a fake `orca` for the ring): `test_ring_reports_a_gone_orca_terminal_as_gone` (A4), `test_ring_keeps_other_orca_failures_as_failed_rings` (A5)
- red against the unchanged library:
  - A4 `not ok - a closed Orca terminal should return 3 from the ring, got 2`
  - A5 was green before the change: it pins that another failure stays 2 and a started receipt stays 0.
- green: `fm_task_inbox_ring` keeps the verdict of a nonzero send and maps `terminal-gone` to 3. Both tests pass.
- refactor: none.
- docs: the ring's header names the new way to reach 3, and `fm_backend_send_text_submit`'s header names the `terminal-gone` verdict.
- live lab (`tests/fm-backend-orca-smoke.test.sh`), observed red before this cycle: `not ok - F: the doorbell to a closed terminal was not reported as gone (missing: 'has exited')`, with the adapter-level live and closed sends already passing.

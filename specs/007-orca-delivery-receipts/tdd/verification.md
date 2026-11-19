# TDD Verification: Orca Delivery Receipts

Verdict: PASS, with the one limitation named below.

## Test-first evidence

`tdd/cycle-log.md` records, for each cycle, the red output against the unchanged adapter and ring library before the implementation, and the green run after.
Two tests were green before the change by design (U13 and A6 pin the no-capability path; A5 pins the unchanged failure mapping) and are covered by mutants below.

## Mutation evidence

No mutation tool is installed, so deliberate mutants were applied to a scratch copy of the changed files and the named tests re-run.

| mutant | killed by |
| --- | --- |
| capability gate always true | `test_failed_status_read_selects_the_current_path`, `test_fm_send_without_the_capability_is_unchanged` |
| replay drops the request id | `test_receipt_accepted_is_replayed_by_id`, `test_receipt_exhausted_with_empty_composer_is_empty` |
| gone set loses `terminal_handle_stale` | `test_receipt_class_matrix`, `test_receipt_gone_terminal_is_terminal_gone` |
| gone set widened to `runtime_error` | `test_receipt_class_matrix`, `test_receipt_other_failures_stay_send_failed` |
| budget off by one | `test_receipt_exhausted_with_empty_composer_is_empty`, `test_receipt_exhausted_with_unreadable_composer_is_pending` |
| pending composer retypes the text | `test_receipt_exhausted_with_pending_composer_retries_enter_only` |
| ring ignores `terminal-gone` | `test_ring_reports_a_gone_orca_terminal_as_gone` |
| unsupported receipt is replayed | `test_receipt_unsupported_falls_back_to_the_composer` |
| started receipt reads `pending` | `test_receipt_started_is_empty` |
| gone verdict exits 0 | `test_receipt_gone_terminal_is_terminal_gone` |
| ring maps every nonzero send to gone | first survived (the failure mapping was only reachable through a verdict that exits 0); `test_ring_keeps_other_orca_failures_as_failed_rings` gained a backend the dispatcher cannot source, which kills it |
| wait window default 5 | `test_receipt_started_is_empty` |

## Acceptance coverage

Every acceptance scenario US1 to US4 maps to a test in `tdd/test-list.md`; US5 is the lab (`tests/fm-backend-orca-smoke.test.sh`, `passed=43`).

## Limitation

A `turn_started` receipt is covered by fake receipts only: the lab has no agent that starts a turn.

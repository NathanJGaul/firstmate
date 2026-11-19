---
feature: 007-orca-delivery-receipts
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 17
planned_at: 46987259
updated_at: 46987259
suite_baseline: unknown
---

# Test List: Orca Delivery Receipts

Baseline note: the suites that exercise the changed code are run green before any edit; the profile's full suite is left to CI, so `suite_baseline` is `unknown`.
`traces` values name spec acceptance scenarios (`USn.m`), functional requirements (`FR-nnn`), and the spec's edge cases (`EC`).
Fake receipts use the shapes the lab recorded; the lab's own assertions (A8, A12, and the firstmate-level steps) are the live proof and are not counted in the table.

## Outer loop: acceptance behaviors

Each runs through a real entry point: `bin/fm-send.sh` (typed and doorbell planes) driving the real adapter against a fake `orca`, or `fm_task_inbox_ring` and the watcher's ring.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | A typed `fm-send` to an Orca task whose runtime lists the receipt capability issues one `terminal send --enter --wait-submit` and no composer read, and exits 0 on a started receipt | US1.1, US1.2, FR-001, FR-002 | example | DONE | `tests/fm-backend-orca.test.sh::test_fm_send_typed_uses_the_receipt_on_orca` |
| A2  | The doorbell for an Orca task rides the same receipt path and `fm-send` exits 0 | US1.1, FR-002 | example | DONE | `tests/fm-backend-orca.test.sh::test_fm_send_doorbell_uses_the_receipt_on_orca` |
| A3  | A typed `fm-send` to a gone Orca terminal exits nonzero and says the terminal is gone and nothing was delivered | US3.3, FR-009 | example | DONE | `tests/fm-backend-orca.test.sh::test_fm_send_typed_names_a_gone_terminal` |
| A4  | `fm_task_inbox_ring` returns 3 for a gone Orca terminal, leaves the record, and types nothing further | US3.2, FR-008 | example | DONE | `tests/fm-task-inbox.test.sh::test_ring_reports_a_gone_orca_terminal_as_gone` |
| A5  | `fm_task_inbox_ring` still returns 2 for any other Orca send failure and 0 for a delivered receipt | FR-006, FR-008 | example | DONE | `tests/fm-task-inbox.test.sh::test_ring_keeps_other_orca_failures_as_failed_rings` |
| A6  | With no receipt capability, a typed `fm-send` issues exactly the literal send, Enter, and composer reads it issued before this change, and no `--wait-submit` | US4.1, FR-007 | characterization | DONE | `tests/fm-backend-orca.test.sh::test_fm_send_without_the_capability_is_unchanged` |

## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | `fm_backend_orca_has_capability` is true only when the status list names the capability, and false for a missing list, a failed call, and invalid JSON | US4.1, US4.2, FR-001, FR-007 | example | DONE | `tests/fm-backend-orca.test.sh::test_has_capability_reads_the_status_list` |
| U2  | `fm_backend_orca_receipt_class` maps started, accepted, unsupported (plain shell and old host), gone, and failed answers, including invalid JSON and empty input | FR-002, FR-004, FR-005, FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_class_matrix` |
| U3  | A started receipt yields `empty` after one send and no composer read | US1.2, US1.3, FR-003 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_started_is_empty` |
| U4  | An accepted receipt is replayed with `--retry-request <id>` and the same text, and a started replay yields `empty`; only one send omits the id | US2.1, US2.2, FR-003 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_accepted_is_replayed_by_id` |
| U5  | A receipt unproven for the whole budget, with an empty composer, yields `empty` after exactly the budgeted observations and no second unnumbered send | US2.3, FR-003 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_exhausted_with_empty_composer_is_empty` |
| U6  | The same with a proven-pending composer retries Enter only, never retypes, and ends on the composer verdict | US2.3, FR-003 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_exhausted_with_pending_composer_retries_enter_only` |
| U7  | The same with an unreadable composer yields `pending` | US2.3, FR-003 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_exhausted_with_unreadable_composer_is_pending` |
| U8  | An unsupported receipt is never replayed; an empty composer yields `empty` and a pending one retries Enter only | US2.4, FR-004 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_unsupported_falls_back_to_the_composer` |
| U9  | A gone answer prints `terminal-gone`, exits 1, and names the terminal and the runtime code on stderr | US3.1, FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_gone_terminal_is_terminal_gone` |
| U10 | Any other failure, including a stale handle, yields `send-failed` and exits 0 | US3.4, FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_other_failures_stay_send_failed` |
| U11 | The wait window defaults to 2 seconds and `FM_ORCA_SUBMIT_WAIT` overrides it | EC, FR-002 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_wait_window_is_tunable` |
| U12 | Text with quotes, a leading dash, and a newline is passed as one argument on every send and replay | EC, FR-002 | example | DONE | `tests/fm-backend-orca.test.sh::test_receipt_text_is_one_argument` |
| U13 | A failed status read selects the current path, byte-identical to before | US4.2, FR-007 | characterization | DONE | `tests/fm-backend-orca.test.sh::test_failed_status_read_selects_the_current_path` |

---
feature: 007-orca-escape-delivery
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: 46987259
updated_at: 46987259
suite_baseline: unknown
---

# Test List: Orca Escape and Ctrl+U Delivery

Baseline note: `tests/fm-backend-orca.test.sh` and `tests/fm-control.test.sh` are run before any edit; the profile's full suite is left to CI, so `suite_baseline` is `unknown`.
`traces` values name spec acceptance scenarios (`USn.m`), functional requirements (`FR-nnn`), and the spec's edge cases (`EC`).

## Outer loop: acceptance behaviors

Each runs through a real entry point: `bin/fm-control.sh`, `bin/fm-send.sh`, or, live, `tests/fm-backend-orca-smoke.test.sh`.

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | An Escape harness interrupted on Orca sends exactly one raw ESC through `terminal send`, with no `--enter` and no `--interrupt` | US1.1, FR-005 | example | DONE | `tests/fm-control.test.sh::test_orca_delivers_an_escape_harness_interrupt` |
| A2 | A composer-restoring harness gets ESC then Ctrl+U, in that order | US1.2, FR-005 | example | DONE | `tests/fm-control.test.sh::test_orca_interrupt_follows_a_composer_restoring_harness_with_ctrl_u` |
| A3 | A Ctrl+C harness on Orca still sends one `--interrupt` and needs no capability | US1.3, FR-008 | example | DONE | `tests/fm-control.test.sh::test_orca_interrupt_for_a_ctrl_c_harness_is_unchanged` |
| A4 | `fm-send --key Escape` on an Orca task sends one raw ESC | US1.4, FR-005 | example | DONE | `tests/fm-control.test.sh::test_fm_send_delivers_escape_to_an_orca_task` |
| A5 | An Escape harness interrupted on a runtime without the capability fails before any send, naming the capability | US2.4, FR-007 | example | DONE | `tests/fm-control.test.sh::test_orca_refuses_an_escape_interrupt_without_the_capability` |
| A6 | `exit` and `relaunch` on Orca stay refused and send nothing | US4.1, FR-010 | example | DONE | `tests/fm-control.test.sh::test_orca_refuses_exit_and_relaunch` |
| A7 | Live: the adapter, `fm-send`, and `fm-control interrupt` reach a real Orca terminal as `^[`, and Ctrl+U clears a typed line | FR-012, SC-003 | live | DONE | `tests/fm-backend-orca-smoke.test.sh` sections A5 and F |

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | The key table lists Escape, Enter, C-c, and C-u for Orca and nothing else | FR-009 | example | DONE | `tests/fm-control.test.sh::test_backend_key_capability_matrix` |
| U2 | `send_key Escape` sends the single ESC byte as `--text`, with no `--enter` and no `--interrupt` | FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_send_key_escape_sends_a_raw_escape_byte` |
| U3 | `send_key C-u` sends the single Ctrl+U byte the same way | FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_send_key_ctrl_u_sends_a_raw_nak_byte` |
| U4 | Every accepted spelling of both keys sends | FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_send_key_escape_and_ctrl_u_accept_their_spellings` |
| U5 | Without the capability both keys send nothing and the message names the capability and version | US2.1, FR-007 | example | DONE | `tests/fm-backend-orca.test.sh::test_send_key_refuses_escape_and_ctrl_u_without_the_capability` |
| U6 | An unreadable status sends nothing | US2.2, FR-007 | example | DONE | `tests/fm-backend-orca.test.sh::test_send_key_refuses_escape_when_the_status_is_unreadable` |
| U7 | Enter and C-c work on a runtime with no capabilities and never read the status | US2.3, FR-008 | example | DONE | `tests/fm-backend-orca.test.sh::test_send_key_enter_and_ctrl_c_ignore_the_capability_gate` |
| U8 | The runtime check records the version and the space-separated capability list | US3.4, FR-001 | example | DONE | `tests/fm-backend-orca.test.sh::test_runtime_check_records_the_version_and_capabilities` |
| U9 | Versions below the floor are refused, naming both | US3.1, FR-002 | property-like examples | DONE | `tests/fm-backend-orca.test.sh::test_runtime_check_refuses_a_version_below_the_floor` |
| U10 | The floor and later versions pass, compared numerically, with suffixes ignored | US3.2, FR-004, EC | property-like examples | DONE | `tests/fm-backend-orca.test.sh::test_runtime_check_accepts_the_floor_and_anything_above_it` |
| U11 | An absent or unreadable version is not refused and enables no capability | US3.3, FR-003, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_runtime_check_does_not_refuse_a_missing_or_unreadable_version` |
| U12 | The existing readiness cases still pass | FR-001 | guard | DONE | `tests/fm-backend-orca.test.sh::test_runtime_check_accepts_ready_orca_status`, `::test_runtime_check_refuses_unready_orca_status` |

Documentation (FR-011) has no executable test; it is covered by `bin/fm-doc-audience-check.sh` and review.

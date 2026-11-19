---
feature: 008-orca-endpoint-presence
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: 5766667f
updated_at: 5766667f
suite_baseline: unknown
---

# Test List: Orca Endpoint Presence

Baseline note: the suites that exercise the changed code are run green before any edit; the profile's full suite is left to CI, so `suite_baseline` is `unknown`.
`traces` values name spec acceptance scenarios (`USn.m`), functional requirements (`FR-nnn`), and edge cases (`EC`).
Fixtures use the shapes the lab recorded (`research.md`); the lab's own step A13 is the live proof and is not counted in the table.

## Outer loop: acceptance behaviors

Each runs through a real entry point: `fm_backend_target_exists` and `fm_backend_agent_state` from `bin/fm-backend.sh`, `bin/fm-session-start.sh`, or `bin/fm-crew-state.sh`, against a fake `orca`.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | `fm_backend_target_exists orca` succeeds for a live terminal and fails for an exited shell, a closed terminal, a stale handle, and an unreadable answer | US1.1, US1.2, US1.3, US1.4, FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_target_exists_reads_the_four_endpoint_states` |
| A2  | The session-start digest prints `endpoint: alive` for a live Orca terminal and `endpoint: dead` for an exited, closed, and stale one | US2.1, US2.2, FR-008 | example | DONE | `tests/fm-session-start.test.sh::test_orca_endpoint_states_in_the_digest` |
| A3  | `bin/fm-crew-state.sh` reports `backend target gone` for an exited, closed, or stale Orca terminal and never for a live one | US2.3, FR-007 | example | DONE | `tests/fm-backend-orca.test.sh::test_crew_state_reports_a_dead_orca_endpoint_gone` |
| A4  | `bin/fm-crew-state.sh` on an unreadable Orca answer says the endpoint state is unreadable and never `gone` | US2.4, FR-007 | example | DONE | `tests/fm-backend-orca.test.sh::test_crew_state_does_not_call_an_unreadable_orca_endpoint_gone` |
| A5  | `fm_backend_agent_state orca` prints `missing`, `unverified`, `unreadable` and `fm_backend_agent_alive` prints `dead`, `unknown`, `unknown` for gone, live, unreadable | US3.1, US3.2, US3.3, FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_missing_unverified_unreadable` |
| A6  | The control plane's capability table still refuses `exit` and `relaunch` on Orca even when the endpoint reads `missing` | US3.4, FR-009 | characterization | DONE | `tests/fm-backend-orca.test.sh::test_a_missing_orca_endpoint_does_not_unlock_the_control_plane` |

## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | `fm_backend_orca_endpoint_state` maps live, exited, closed, and stale answers to `present`, `missing`, `missing`, `missing` | FR-001, FR-002, FR-003 | example | DONE | `tests/fm-backend-orca.test.sh::test_endpoint_state_four_states` |
| U2  | It reads `unreadable` for connected-but-not-writable, writable-but-not-connected, a handle mismatch, a contradicting `status`, another error code, a missing `result.terminal`, invalid JSON, empty output, and a failing CLI | FR-004, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_endpoint_state_unreadable_matrix` |
| U3  | It issues exactly one `orca terminal show --terminal <handle> --json` and no other `orca` verb | FR-001, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_endpoint_state_is_one_read_only_call` |
| U4  | It reads `unreadable` when no `orca` CLI is reachable | FR-004, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_endpoint_state_without_the_cli_is_unreadable` |
| U5  | A stale answer carried with a failing exit status is `missing`, and an `ok:true` answer with a failing exit status still follows its JSON | FR-003 | example | DONE | covered by `test_endpoint_state_four_states` |
| U6  | `fm_backend_orca_agent_state` maps `present` to `unverified`, `missing` to `missing`, and `unreadable` to `unreadable` | FR-006 | example | DONE | covered by `test_agent_state_missing_unverified_unreadable` |

## Property and approval tests

None: the mapping is a small closed matrix, covered by examples.
No mutation tool is installed; high-risk lines are checked with deliberate mutants recorded in `tdd/verification.md`.

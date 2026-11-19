---
feature: 009-orca-process-classifier
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 18
planned_at: 1ccee8e5
updated_at: 1ccee8e5
suite_baseline: unknown
---

# Test List: Orca Local Process Classifier

Baseline note: the suites that exercise the changed code are run green before any edit; the profile's full suite is left to CI, so `suite_baseline` is `unknown`.
`traces` values name spec acceptance scenarios (`USn.m`), functional requirements (`FR-nnn`), and edge cases (`EC`).
The fake process table is a temporary directory laid out like `/proc` and selected through `FM_ORCA_PROC_ROOT`; the lab's own step A14 is the live proof and is not counted in the table.

## Outer loop: acceptance behaviors

Each runs through a real entry point, `fm_backend_agent_state` and `fm_backend_agent_alive` from `bin/fm-backend.sh`, against a fake `orca` and a fake process table.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | A present terminal whose handle is carried by a shell and a harness-named process reads `alive` | US1.1, FR-004 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_alive_for_a_harness_process` |
| A2  | A harness that does not carry the handle but descends from a process that does reads `alive` | US1.2, FR-001 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_alive_for_a_descendant_harness` |
| A3  | A harness identified only by argv[0] under a bare `node` reads `alive` | US1.3, FR-001 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_alive_for_an_argv0_harness` |
| A4  | Only shells reads `dead`, `fm_backend_agent_alive` reads `dead`, and a zombie harness does not count | US2.1, US2.2, US2.3, FR-002, FR-007 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_dead_for_only_shells` |
| A5  | A process that is neither harness nor shell reads `ambiguous` and `fm_backend_agent_alive` reads `unknown` | US3.1, FR-002 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_ambiguous_for_another_process` |
| A6  | A selected non-local runtime reads `unverified` and the process table is never opened | US3.2, FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_unverified_for_a_non_local_runtime` |
| A7  | A host with no process table, and a handle no local process carries, read `unverified` | US3.3, US3.4, FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_unverified_without_attribution` |
| A8  | An unlistable table, and an unreadable own process with no harness found, read `unreadable`; a harness found beside an unreadable one stays `alive` | US3.5, FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_unreadable_matrix` |
| A9  | A missing or unreadable endpoint keeps `missing` or `unreadable` and reads no process table | US3.6, FR-003 | example | DONE | `tests/fm-backend-orca.test.sh::test_agent_state_endpoint_verdicts_do_not_read_the_table` |
| A10 | The control plane still refuses `exit` and `relaunch` on Orca when the endpoint reads `dead` | US4.1, FR-010 | characterization | DONE | `tests/fm-backend-orca.test.sh::test_a_dead_orca_endpoint_does_not_unlock_the_control_plane` |

## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | The scan keeps only processes holding the exact `ORCA_TERMINAL_HANDLE=<handle>` entry, so `term_1` never matches `term_10` | FR-001, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_process_scan_matches_the_exact_handle` |
| U2  | The scan extends the kept set with every descendant and skips a process of another handle | FR-001 | example | DONE | `tests/fm-backend-orca.test.sh::test_process_scan_includes_descendants` |
| U3  | The scan drops zombies, its own pid, and a process whose directory vanishes | FR-007, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_process_scan_drops_zombies_self_and_vanished` |
| U4  | The scan skips a process of another user without a read or a tally | EC | example | DONE | `tests/fm-backend-orca.test.sh::test_process_scan_skips_other_users` |
| U5  | The scan tallies an unreadable own process and reports `unsupported` without a table and `unreadable` for an unlistable one | FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_process_scan_status_and_tally` |
| U6  | A tab or newline in a process field cannot break a row | EC | example | DONE | `tests/fm-backend-orca.test.sh::test_process_scan_sanitizes_fields` |
| U7  | `fm_backend_orca_process_state` precedence: `agent` beats everything, then `unreadable`, `none`, `shell`, `other` | FR-002, FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_process_state_precedence` |
| U8  | `other` is resampled and a shell reading inside the settle window wins | FR-004, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_process_state_settles_a_transient_other` |
| U9  | The pid is passed to the classifier only for the real `/proc` | FR-001 | example | DONE | covered by A3 and the lab step A14 |
| U10 | A refused own environment is opaque: reached through the tree, not tallied, and a negative verdict is still reachable | FR-006, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_process_scan_opaque_environment_is_reached_through_the_tree` |

## Property and approval tests

None: the mapping is a small closed matrix, covered by examples.
No mutation tool is installed; high-risk lines are checked with deliberate mutants recorded in `tdd/verification.md`.

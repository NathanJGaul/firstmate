# TDD Verification: Orca Endpoint Presence

Verdict: PASS.

## Test-first evidence

Every behavior in `test-list.md` has a red entry in `cycle-log.md`, recorded against the unchanged code before the implementation.
The digest and crew-state reds show the real defect: an exited or closed terminal printed `endpoint: alive` and was never reported gone.

## Test strength

No mutation tool is installed, so deliberate mutants were applied one at a time to the implementation and the affected tests re-run.
All 12 were killed:

| mutant | killed by |
| --- | --- |
| present ignores `writable` | `test_endpoint_state_unreadable_matrix` |
| missing ignores `writable` | `test_endpoint_state_unreadable_matrix` |
| stale handle read as unreadable | `test_endpoint_state_four_states` |
| no handle comparison | `test_endpoint_state_unreadable_matrix` |
| contradicting `status` guard dropped | `test_endpoint_state_unreadable_matrix` |
| any error code read as missing | `test_endpoint_state_unreadable_matrix` |
| unparseable answer read as missing | `test_endpoint_state_unreadable_matrix` |
| `fm_backend_target_exists` succeeds unless unreadable | `test_target_exists_reads_the_four_endpoint_states` |
| Orca arm removed from `fm_backend_agent_state` | `test_agent_state_missing_unverified_unreadable` |
| a present terminal reported `alive` | `test_agent_state_missing_unverified_unreadable` |
| crew state no longer reports `missing` as gone | `test_crew_state_reports_a_dead_orca_endpoint_gone` |
| crew state skips the endpoint read | `test_crew_state_reports_a_dead_orca_endpoint_gone` |

## Acceptance coverage

US1 by A1 and U1 to U5, US2 by A2 to A4, US3 by A5 and A6; FR-011 by lab step A13 (`passed=28 findings=4` Orca-level, `passed=44 findings=5` whole lab).
Suites re-run green after the change: `fm-backend-orca` (346 s), `fm-session-start` (612 s), `fm-crew-state` (402 s), `fm-backend` (151 s).

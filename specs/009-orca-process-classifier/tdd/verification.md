# TDD Verification: Orca Local Process Classifier

Verdict: PASS.

## Test-first evidence

Every behavior in `test-list.md` has a red entry in `cycle-log.md`, recorded against the unchanged code before the implementation, except the three characterizations (A7, A9, the one-orca-call case) that hold before and after and are guarded by mutants.
The refused-environment behavior (U10) was found by the first live run and is recorded as its own cycle.

## Test strength

No mutation tool is installed, so deliberate mutants were applied one at a time to a copy of `bin/backends/orca.sh` and the 20 new test functions re-run.
All 16 were killed:

| mutant | killed by |
| --- | --- |
| a harness never wins | the alive cases |
| other processes counted as shells | `test_agent_state_ambiguous_for_another_process` |
| no carrier reads shell | `test_process_state_precedence` |
| unreadable tally ignored | `test_agent_state_unreadable_matrix` |
| non-local guard removed | `test_agent_state_unverified_for_a_non_local_runtime` |
| descendants not walked | `test_agent_state_alive_for_a_descendant_harness` |
| handle matched as a substring | `test_process_scan_matches_the_exact_handle` |
| zombies kept | `test_agent_state_dead_for_only_shells` |
| refused environment tallied | `test_process_scan_opaque_environment_is_reached_through_the_tree` |
| process table read before the endpoint | `test_agent_state_endpoint_verdicts_do_not_read_the_table` |
| no settle resample | `test_process_state_settles_a_transient_other` |
| scanner's own pid not excluded | `test_process_scan_drops_zombies_self_and_vanished` |
| no carrier reads dead | `test_agent_state_unverified_without_attribution` |
| unsupported table treated as readable | `test_process_scan_status_and_tally` |
| other users' processes can carry | `test_process_scan_skips_other_users` |
| ambiguous reads dead | `test_agent_state_ambiguous_for_another_process` |

## Acceptance coverage

US1 by A1 to A3, US2 by A4 and the lab step A14, US3 by A5 to A9 and U1 to U10, US4 by A10; FR-012 by lab step A14.

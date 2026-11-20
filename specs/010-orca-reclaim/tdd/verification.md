# TDD Verification: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

Verdict: PASS.

## Test-first evidence

Every behavior in `test-list.md` has a red entry in `cycle-log.md`, recorded against the unchanged code before the implementation, except the secondmate and non-local refusals in `test_orca_spawn_relaunch_refuses_what_it_cannot_prove`, which held before through the generic gates and are guarded by mutants M7 and the non-local clause of M2.
The first mutant run found two survivors; each was closed with a new assertion and is recorded as its own cycle.

## Test strength

No mutation tool is installed, so deliberate mutants were applied one at a time to a copy of the production file and the named tests re-run.
All 21 were killed (19 on the first run, the other two after cycle 5):

| mutant | killed by |
| --- | --- |
| absence ignores a lingering shell or harness (M1, M1b) | `test_absence_verdict_for_orca` |
| a non-local runtime proves absence (M2) | `test_absence_verdict_for_orca` |
| `ptyKilled: false` counted as killed (M3) | `test_close_terminal_verdicts` |
| a receipt naming another handle accepted (M3b) | `test_close_terminal_verdicts` |
| the reclaim skips the close (M4) | `test_reclaim_terminal` |
| the reclaim skips the old-terminal check (M4b) | `test_reclaim_terminal` |
| an unconfirmed replacement left behind (M4c) | `test_reclaim_terminal` |
| the reclaim skips the listing check (M4d) | `test_reclaim_terminal` |
| a running agent closed without the flag (M6) | `test_orca_exit_matrix` |
| the flag accepted for a non-alive state (M6b) | `test_orca_close_terminal_is_bounded` |
| an unclassifiable interrupt dies (M8) | `test_orca_interrupt_keeps_endpoint_proof` |
| the close skips its confirmation wait (M9) | `test_orca_exit_close_terminal` |
| the close ignores a bad receipt (M9b) | `test_orca_exit_close_terminal` |
| the abort leaves the created terminal (M5) | `test_orca_failed_reclaim_keeps_the_record` |
| an Orca secondmate accepted (M7) | `test_orca_spawn_relaunch_refuses_what_it_cannot_prove` |
| the republished record loses the worktree id (M10) | `test_orca_relaunch_adopts_a_dead_terminal` |
| the runtime is not checked (M11) | `test_orca_relaunch_checks_the_runtime` |
| the new terminal is not republished (M12) | `test_orca_relaunch_reclaims_a_gone_terminal` |
| Orca not admitted (M13) | `test_state_verified_backends_are_tmux_herdr_and_orca`, `test_orca_exit_matrix` |

## Acceptance coverage

US1 by A1, A4, and lab step A15 (killed harness); US2 by A2, A5, A9, and lab step A15 (closed terminal); US3 by A3, A6, A7, and lab step A15 (running agent); US4 by A3, A8, and the non-local and lingering cases; US5 by lab step A15 (teardown).
FR-001 by U1; FR-002 by A1-A3; FR-003 and FR-004 by A6, A8, U2; FR-005 by U3; FR-006 and FR-007 by A4, A5, U4; FR-008 by A9; FR-009 by the `worktree` assertions in A5, A7, A9; FR-010 by U6; FR-011 by the secondmate case; FR-012 by U5; FR-013 by the documentation review in `analyze.md`.

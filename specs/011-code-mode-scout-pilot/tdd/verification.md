# TDD Verification: Code Mode Scout Pilot

Verified from a cold read of the diff, the test list, and the cycle log.

## Test-first evidence

- Cycle 1 (launch line) and cycle 4 (engine) were seen red for the right reason before their implementation; the first assertions failed with the unchanged launch line and with the inherited variable respectively (`tdd/cycle-log.md`).
- Cycles 2, 3, and 5 are characterizations whose strength is carried by mutants, listed below.
- The documentation and the live E2E have no automated red phase; the live E2E is opt-in and its offline guard paths (gate skip, absent login, forbidden real store, relative path) were exercised by hand.

## Test-smell rubric

- Every assertion reads the captured launch line, the spawn output, the worker's observed environment (a fake claude launched through the real `env -i` wrapper), or library return values; none reads source bytes.
- The environment assertions execute the captured launch the way the pane shell does, so they fail if the assignment or the unset is not in effect, not merely absent from a string.
- The skip-note assertions count lines, so a duplicate note fails.

## Mutation evidence (deliberate mutants)

No mutation tool is installed, so each mutant is a hand edit applied to a scratch copy of the tree, run against `tests/fm-spawn-claude-code-mode.test.sh`, and discarded.
All eleven were caught.

| Id | Mutant | First failing assertion |
| --- | --- | --- |
| M1 | the default `-u` token dropped | scout launch must unset the variable when the knob is absent |
| M2 | acceptance never checked | the spawn output must say Code Mode was skipped |
| M3 | pinned root ignored, `$HOME` read | acceptance in the pinned root must enable Code Mode |
| M4 | auto permission mode allowed | a scout under auto mode must unset the variable |
| M5 | kind check removed, ships and secondmates qualify | the ship launch must keep the unset form |
| M6 | acceptance read as `!= false` | the no-store case: skipped note missing |
| M7 | any token accepted by the library | `maybe` must refuse the spawn |
| M8 | the engine keeps the variable | the supervision engine inherited the variable |
| M9 | the knob added to the inherited set | the knob must stay a per-home choice |
| M10 | a bad knob falls back to off | `maybe` must refuse the spawn |
| M11 | raw launch commands touched | a raw launch command is launched verbatim |

## Acceptance-criteria coverage

| Criterion | Test |
| --- | --- |
| US1.1 to US1.3 | `test_absent_knob_unsets_the_variable_for_scouts_and_ships`, `test_scouts_knob_enables_only_scouts_with_recorded_acceptance`, `test_scouts_knob_never_reaches_a_secondmate` |
| US1.4, US1.5 | `test_launch_env_allowlist_does_not_decide` and the stray-variable assertions above |
| US1.6 | `test_invalid_knob_refuses_before_any_record` |
| US1.7 | `test_auto_permission_mode_keeps_scouts_off_with_a_reason` |
| US1.8 | `test_other_harnesses_and_raw_commands_are_untouched` |
| US2.1, US2.2, US2.3 | `test_unaccepted_dialog_skips_with_one_explanatory_line`, `test_pinned_account_root_decides_acceptance` |
| US2.4 | `test_library_parses_the_knob_and_reads_the_store_without_writing` |
| US3.1 | `test_scouts_knob_never_reaches_a_secondmate` |
| US3.2 | `test_supervision_engine_never_inherits_the_variable` |
| US4.1 to US4.4 | `tests/fm-claude-codemode-live-e2e.test.sh` (opt-in; passed on Claude Code 2.1.328, 2026-11-20) |
| US5.1 to US5.3 | `bin/fm-doc-audience-check.sh` plus review of `docs/configuration.md`, the spawn header, and the adapter reference |

Known limitation: relaunch re-enters the same launch construction as a fresh spawn, and the portable suite does not drive `--relaunch` separately.

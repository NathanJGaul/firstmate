# Cycle Log: Code Mode Scout Pilot

Append only. Newest last.

## Baseline

- Before any edit, `tests/fm-spawn-dispatch-profile.test.sh`, `tests/fm-worker-account.test.sh`, `tests/fm-claude-trust.test.sh`, `tests/fm-secondmate-harness.test.sh`, `tests/fm-backend-orca.test.sh`, and `tests/fm-supervision-host.test.sh` are the suites that pin the claude launch line or the engine; they run again after the change (below).
- The full profile suite is left to CI.

Method notes:

- The new portable suite is one file, so each red was observed by running the whole file against unchanged code (the library did not exist yet) and then against the partial implementation; the first failing assertion is recorded per cycle.
- Tests, implementation, docs, and this log land together on the branch.

## Cycle 1: the launch line states Code Mode explicitly (O1, O2, O3)

- tests (new): `test_absent_knob_unsets_the_variable_for_scouts_and_ships`, `test_scouts_knob_enables_only_scouts_with_recorded_acceptance`, `test_scouts_knob_never_reaches_a_secondmate`
- red: `not ok - scout launch must unset the Code Mode variable when the knob is absent (missing: '-u GEMINI_CLI -u CLAUDE_CODE_EXPERIMENTAL_CODE_MODE CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false')`, with the unchanged launch line printed.
- green: the knob resolved beside `config/claude-permission-mode`, and the token spliced into the existing `env -u CURSOR_AGENT ...` prefix.
- note: the first implementation sourced `bin/fm-claude-code-mode-lib.sh` after the resolution call, which the suite caught as `fm_claude_code_mode_setting: command not found` (exit 1); the source moved above the call.

## Cycle 2: the allowlist and a stray environment do not decide (O4, O5)

- test (new): `test_launch_env_allowlist_does_not_decide`, which executes the captured launch (including the real `env -i` wrapper) with a fake claude that records the variable.
- red: none observable as a separate step, because the launch-line splice of cycle 1 already puts both forms inside the wrapped line; the test is a characterization whose strength is shown by mutants M2 and M3 in `tdd/verification.md`.

## Cycle 3: refusals, the dialog skip, auto mode, pinned root, untouched cases (O6 to O11)

- tests (new): `test_invalid_knob_refuses_before_any_record`, `test_unaccepted_dialog_skips_with_one_explanatory_line`, `test_pinned_account_root_decides_acceptance`, `test_auto_permission_mode_keeps_scouts_off_with_a_reason`, `test_other_harnesses_and_raw_commands_are_untouched`
- red and green share cycle 1's implementation, which contained the refusal, the acceptance read, the note lines, and the bypass-only rule; each assertion was exercised by a mutant instead (M4 to M8).

## Cycle 4: the supervision engine never inherits the variable (O13)

- test (new): `test_supervision_engine_never_inherits_the_variable`, calling `fm_supervision_engine_turn` with a stub engine that records its environment.
- red: `not ok - the supervision engine inherited CLAUDE_CODE_EXPERIMENTAL_CODE_MODE from the host's environment`.
- green: `unset CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` in the engine's subshell before it execs the bounded engine.

## Cycle 5: library and inheritance (I1 to I3)

- tests (new): `test_library_parses_the_knob_and_reads_the_store_without_writing`, `test_knob_is_not_inherited_into_secondmate_homes`; both green on first run because the library shipped with cycle 1.

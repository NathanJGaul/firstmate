---
feature: 004-worker-browser-session
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 18
planned_at: af20b2c9
updated_at: 0f7b838e
suite_baseline: green
---

# Test List: Per-Worker Browser Session

Trace ids: `US<n>.<m>` is acceptance scenario `<m>` of user story `<n>` in `spec.md`, and `FR-<n>` is a functional requirement.

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`.
Each is observed through the real entry point: the spawn script and its emitted launch command run in a synthetic pane, or the teardown script run against a sandbox home with a fake `chrome-devtools-axi` first on `PATH`.

| id  | behavior                                                                                                                | traces              | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------------- | ------------------- | ------- | ------- | ---- |
| A1  | A ship worker launched with no allowlist starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its task id                  | US1.1, US2.3, FR-001 | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_ship_launch_exports_its_task_id_as_the_session` |
| A2  | A scout worker starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its task id                                           | US1.2, FR-001       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_scout_launch_exports_its_task_id_as_the_session` |
| A3  | A local secondmate starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its own id                                        | US1.3, FR-001       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_secondmate_launch_exports_its_id_as_the_session` |
| A4  | A pane already carrying another `CHROME_DEVTOOLS_AXI_SESSION` still yields the task id                                  | US1.4, FR-002       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_launch_overrides_a_session_already_in_the_pane` |
| A5  | A relaunch through `fm-control.sh relaunch` yields the same task-id session for the replacement agent                   | US1.5, FR-001       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_relaunch_keeps_the_task_id_session` |
| A6  | Two workers with different task ids start with different sessions                                                       | US1.6, FR-001       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_two_workers_get_different_sessions` |
| A7  | Under a present, empty allowlist the cleared-environment launch still yields the task-id session                        | US2.1, FR-003       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_survives_an_empty_allowlist` |
| A8  | Replaying only the launch command, without the pane-side exports, yields the task id in both allowlist postures         | US2.2, FR-003       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_does_not_depend_on_the_pane_exports` |
| A9  | Cleanup of a task whose launch exported a session runs `chrome-devtools-axi stop` once with that session                | US3.1, FR-005       | example | DONE | `tests/fm-teardown.test.sh::test_teardown_stops_the_task_browser_session` |
| A10 | The stop happens after the leaked-process cleanup for the task                                                          | US3.2, FR-006       | example | DONE | `tests/fm-teardown.test.sh::test_browser_session_stop_follows_the_leaked_process_reap` |
| A11 | A stop that exits non-zero, or that exceeds its bound, leaves cleanup complete with an unchanged exit status and a warning | US3.3, FR-007, FR-008 | example | DONE | `tests/fm-teardown.test.sh::test_a_failing_browser_stop_never_blocks_teardown` |
| A12 | With no `chrome-devtools-axi` on `PATH`, cleanup completes with no warning and no error                                 | US3.4, FR-007       | example | DONE | `tests/fm-teardown.test.sh::test_teardown_without_the_browser_tool_is_silent` |
| A13 | A cleanup that refuses because work is unlanded issues no stop                                                          | US3.5, FR-006       | example | DONE | `tests/fm-teardown.test.sh::test_a_refused_teardown_never_stops_the_browser_session` |
| A14 | A spawn for a task whose id is `default` exports no `CHROME_DEVTOOLS_AXI_SESSION` of its own                            | US4.1, FR-004       | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_default_named_task_exports_no_session` |
| A15 | Cleanup of a task whose id is `default` issues no stop                                                                  | US4.2, FR-009       | example | DONE | `tests/fm-teardown.test.sh::test_a_default_named_task_never_stops_the_default_session` |
| A16 | Cleanup run by a caller whose environment names another session still stops the task's id                                | US4.3, FR-005, FR-009 | example | DONE | `tests/fm-teardown.test.sh::test_the_stop_names_the_task_not_the_callers_session` |
| A17 | Cleanup of a legacy path-safe id longer than 64 characters issues no stop                                               | US4.4, FR-004, FR-009 | example | DONE | `tests/fm-teardown.test.sh::test_an_overlong_legacy_id_never_stops_a_browser_session` |

## Inner loop: unit behaviors

### `bin/fm-pr-lib.sh` (`fm_browser_session_name`)

| id  | behavior                                                                  | traces        | kind    | state   | test |
| --- | ------------------------------------------------------------------------- | ------------- | ------- | ------- | ---- |
| U1  | Prints a creation-valid id unchanged and returns 0                        | FR-001, FR-010 | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_accepts_a_task_id` |
| U2  | Accepts dots, underscores, and hyphens inside an id                       | FR-010        | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_accepts_dots_underscores_and_hyphens` |
| U3  | Accepts an id of exactly 64 characters                                    | FR-010        | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_accepts_a_64_character_id` |
| U4  | Refuses an id of 65 characters with status 1 and no output                | FR-004, FR-010 | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_refuses_a_65_character_id` |
| U5  | Refuses exactly `default` with status 1 and no output                     | FR-004, FR-009 | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_refuses_the_default_session` |
| U6  | Accepts ids that merely contain or extend `default`, such as `default-2`  | FR-004        | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_accepts_ids_that_extend_default` |
| U7  | Refuses an empty id                                                       | FR-004        | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_refuses_an_empty_id` |
| U8  | Refuses an id with a leading dot                                          | FR-004        | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_refuses_a_leading_dot` |
| U9  | Refuses an id containing a space or other character outside `[A-Za-z0-9._-]` | FR-004     | example | DONE | `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_refuses_characters_the_tool_rejects` |

### `bin/fm-teardown.sh` (stop bound)

| id  | behavior                                                                                              | traces        | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | ---- |
| U10 | A stop that hangs is ended at the configured bound and cleanup proceeds                               | FR-008        | example | DONE | `tests/fm-teardown.test.sh::test_a_hung_browser_stop_is_cut_off_at_its_bound` |
| U11 | A non-numeric bound value falls back to the default instead of aborting cleanup                       | FR-007, FR-008 | example | DONE | `tests/fm-teardown.test.sh::test_a_non_numeric_stop_bound_falls_back_to_the_default` |

## Invariants and edge cases still to place

- The launch for a relaunch keeps the same session name as the original launch (covered by A5).
- Cleanup of a task spawned before this change stops a session that does not exist and is a no-op (not testable without the real tool; recorded in the specification's edge cases).

## Out of scope

- Remote secondmates: they never pass through the local launch path, and their coverage stays in `tests/fm-spawn-compact-adviser-disable-remote.test.sh`.
- Port collisions between session names, an operator-set `CHROME_DEVTOOLS_AXI_PORT`, and two homes sharing a task id: documented as residual risks in the specification and not testable without the real tool.
- Recycling existing default bridges: not part of this feature.
- A live check with the real `chrome-devtools-axi`: the tool is not a harness whose rendered output is parsed, so the fake proves Firstmate's side; the real tool's `stop` semantics are recorded in `research.md` from its source.

## Verification commands

Copied from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `bin/fm-test-run.sh {file}`
- Full suite: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`
- Coverage (runner inventory guard): `bin/fm-test-run.sh --check-coverage`
- Mutation: none installed; high-risk behavior is checked with deliberate mutants recorded in `tdd/verification.md`

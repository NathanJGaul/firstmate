---
feature: 005-orca-fleet-plumbing
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 15
planned_at: 018cde5d
updated_at: 018cde5d
suite_baseline: unknown
---

# Test List: Orca Fleet Plumbing

Baseline note: the four suites that exercise the changed code are run green before any edit; the profile's full suite is left to CI, so `suite_baseline` is `unknown`.
`traces` values name spec acceptance scenarios (`USn.m`), functional requirements (`FR-nnn`), and the spec's edge cases (`EC`).

## Outer loop: acceptance behaviors

Each runs through a real entry point: `bin/fm-bootstrap.sh`, `bin/fm-spawn.sh --backend orca`, `bin/fm-watch.sh`, or the daemon classifier.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | In a tmux home with a live task recorded on `orca` and `orca` absent, bootstrap reports `orca` missing | US1.1, FR-001 | example | DONE | `tests/fm-bootstrap.test.sh::test_bootstrap_checks_the_backend_a_live_task_runs_on` |
| A2  | The same fleet with `orca` present is silent | US1.2, FR-001 | example | DONE | `tests/fm-bootstrap.test.sh::test_bootstrap_checks_the_backend_a_live_task_runs_on` |
| A3  | In an orca home, a task record with no backend field makes bootstrap report `tmux` and `treehouse` when absent | US1.3, FR-002 | example | DONE | `tests/fm-bootstrap.test.sh::test_bootstrap_treats_an_unrecorded_task_backend_as_tmux` |
| A4  | A tool required by two recorded backends is reported once | US1.4, FR-004 | example | DONE | `tests/fm-bootstrap.test.sh::test_bootstrap_reports_a_shared_tool_once` |
| A5  | With no task records, output for each default backend is unchanged | US1.5, FR-006 | example | DONE | `tests/fm-bootstrap.test.sh::test_bootstrap_without_task_records_is_unchanged` |
| A6  | A task recorded on an unknown backend adds nothing and the default's invalid diagnostic is unchanged | EC, FR-003 | example | DONE | `tests/fm-bootstrap.test.sh::test_bootstrap_ignores_an_unknown_recorded_backend` |
| A7  | The treehouse lease check runs when only a recorded task's backend uses treehouse | FR-005 | example | DONE | `tests/fm-bootstrap.test.sh::test_treehouse_lease_check_follows_recorded_backends` |
| A8  | An Orca launch under an empty allowlist hands the harness every observed `ORCA_` variable the terminal carries, with its value | US2.1, FR-007 | example | TODO | `tests/fm-spawn-orca-worktree.test.sh::test_orca_allowlisted_launch_keeps_the_orca_floor` |
| A9  | A floor name the terminal lacks stays unset in the harness | US2.2, FR-007 | example | TODO | `tests/fm-spawn-orca-worktree.test.sh::test_orca_allowlisted_launch_keeps_the_orca_floor` |
| A10 | An `ORCA_` name outside the observed set, and an unrelated name, are removed | US2.3, FR-008 | example | TODO | `tests/fm-spawn-orca-worktree.test.sh::test_orca_allowlisted_launch_keeps_the_orca_floor` |
| A11 | With no allowlist file the launch text names no floor variable | US2.4, FR-008 | example | TODO | `tests/fm-spawn-orca-worktree.test.sh::test_orca_launch_without_an_allowlist_is_unfiltered` |
| A12 | The watcher's stale wake for an Orca task reads `stale: fm-<id>` and the queued key is the terminal handle | US3.1, US3.4, FR-010, FR-012 | example | TODO | `tests/fm-watch-triage.test.sh::test_orca_stale_wake_names_the_task_and_routes_by_handle` |
| A13 | A detail-suffixed stale reason from the watcher keeps its suffix after the label | FR-013 | example | TODO | `tests/fm-watch-triage.test.sh::test_orca_wedge_wake_keeps_its_detail_after_the_label` |
| A14 | The daemon classifies a label-form stale reason to the same task and markers as the handle form | US3.5, FR-014 | example | TODO | `tests/fm-daemon.test.sh::test_stale_label_form_resolves_the_same_task_and_markers` |

## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | `fm_backend_fleet_required_tools` prints the default's tools first, then each recorded backend's new tools, each once | FR-001, FR-004 | example | DONE | `tests/fm-bootstrap.test.sh::test_fleet_required_tools_orders_default_first` |
| U2  | `window_wake_name` returns `fm-<id>` for a Herdr or Orca handle that a task record resolves | US3.1, US3.2, FR-010 | example | TODO | `tests/fm-watch-triage.test.sh::test_window_wake_name_labels_opaque_handles` |
| U3  | `window_wake_name` returns the handle when no task record resolves it | US3.6, FR-011 | example | TODO | `tests/fm-watch-triage.test.sh::test_window_wake_name_keeps_unresolved_handles` |
| U4  | `window_wake_name` returns a handle that already ends in `fm-<id>` unchanged | US3.3, FR-011 | example | TODO | `tests/fm-watch-triage.test.sh::test_window_wake_name_keeps_readable_handles` |
| U5  | `window_to_task` is unchanged for matching, `terminal=` matching, and fallback | FR-014 | characterization | TODO | `tests/fm-watch-triage.test.sh::test_window_to_task_resolves_opaque_backend_target_through_metadata` |

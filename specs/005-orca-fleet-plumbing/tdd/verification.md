---
feature: 005-orca-fleet-plumbing
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: e2a55d25
behaviors: 19
proven: 14
likely: 0
test_after: 0
no_test: 0
guard_green_first: 5
high_smells: 0
criteria_total: 15
criteria_covered: 15
mutation_score: not measured by a tool; 4 of 4 deliberate mutants killed (scope - bin/fm-backend.sh, bin/fm-classify-lib.sh)
mutants_survived: 0
suite: tests/fm-bootstrap.test.sh, tests/fm-spawn-orca-worktree.test.sh, tests/fm-watch-triage.test.sh, tests/fm-daemon.test.sh, tests/fm-task-inbox.test.sh all pass on the final rule
---

# TDD Verification: Orca Fleet Plumbing

**Verdict: PASS.** Every behavior that changed has a recorded red before its change, tests and implementation share one commit per cycle, every acceptance criterion is covered through a real entry point, and every sampled mutant is killed.

## Behavior evidence

| id | evidence | classification |
| -- | -------- | -------------- |
| A1, A3, A4, A7, U1 | red recorded in cycle 1, green after `fm_backend_fleet_required_tools` | PROVEN |
| A8, A9, A10 | red recorded in cycle 2 (`dropped ORCA_AGENT_HOOK_ENDPOINT`), green after the floor change | PROVEN |
| A12, A13, U2 | red recorded in cycle 3 (`got: stale: term_...`), green after `window_wake_name` | PROVEN |
| U3, U4 | red was `command not found`; assertions are non-vacuous because the mutant below fails U4 | PROVEN |
| A2 | asserted in the same function as A1; red covered by A1's red | PROVEN |
| A5, A6, A11, A14, U5 | green before the change by design: each pins behavior that must stay unchanged (see below) | guard, green first |

## Guard tests that were green first

- A5 (no task records leaves bootstrap unchanged): mutant `order="$default tmux"` makes it fail with `MISSING: tmux` in an orca home.
- A6 (unknown recorded backend adds nothing): the unknown-backend skip is redundant with `fm_backend_required_tools` rejecting it, so a mutant removing `fm_backend_is_known` is equivalent and survives by construction; the observable behavior is pinned and no behavior depends on that line alone.
- A11 (no allowlist leaves the launch unfiltered): it fails for any change that forces the cleared environment on every launch.
- A14 (the daemon resolves a label-form reason): mutant removing the `fm-` strip in `window_to_task`'s fallback fails with `.subsuper-stale-fm-her-w1` versus `.subsuper-seen-status-her-w1`.
- U5 (`window_to_task` output unchanged by the refactor): the existing assertions run in the same suite and stay green.

## Deliberate mutants

| mutant | file | killed by |
| ------ | ---- | --------- |
| the default's order gains an unconditional `tmux` | `bin/fm-backend.sh` | `test_bootstrap_without_task_records_is_unchanged` |
| the per-tool de-duplication removed | `bin/fm-backend.sh` | `test_bootstrap_reports_a_shared_tool_once` |
| the `fm-` strip removed from `window_to_task`'s fallback | `bin/fm-classify-lib.sh` | `test_stale_label_form_resolves_the_same_task_and_markers` |
| the "already named" `fm-*` case disabled | `bin/fm-classify-lib.sh` | `test_window_wake_name_keeps_readable_handles` |

## Test-smell rubric

No test asserts implementation-source bytes.
The launch-env cases execute the emitted launch under a synthetic terminal environment and read what the harness process receives.
The bootstrap cases run the real script against fake toolchains, and the watcher cases run the real watcher against a fake `orca`.
The only text assertions are on wake reasons, which are the product output under test.

## Traceability

All criteria (US1.1-5, US2.1-4, US3.1-6, and FR-001 to FR-014) trace to at least one test in `test-list.md`; US3.2 (Herdr handle) is covered at the function level by U2 and US3.5 by A14.

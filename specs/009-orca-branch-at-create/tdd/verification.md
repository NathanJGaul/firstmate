# TDD Verification: Orca Branch At Create

Verdict: PASS.

## Test-first evidence

Every behavior in `test-list.md` has a red entry in `cycle-log.md`, recorded against the unchanged code before the implementation, except A3, a deliberate characterization that already held.
The live lab supplied the red for the one gap the fixtures could not see: Orca hands `--base-branch` to git verbatim, so an origin-only base failed with `invalid reference` and the spawn exited silently.
That produced two further tests, each seen failing first.

## Test strength

No mutation tool is installed, so deliberate mutants were applied one at a time to a scratch copy of the implementation and the test meant to kill each was re-run.
All 12 were killed:

| mutant | killed by |
| --- | --- |
| adapter drops `--branch` | `test_worktree_create_passes_branch_and_base` |
| adapter drops `--base-branch` | `test_worktree_create_passes_branch_and_base` |
| adapter always passes a base | `test_worktree_create_without_branch_is_unchanged` |
| adapter swallows Orca's refusal | `test_worktree_create_failure_names_orca_s_reason` |
| a scout names a branch | `test_orca_scout_spawn_passes_no_branch` |
| spawn skips the branch read-back | `test_orca_spawn_refuses_a_renamed_branch` |
| spawn passes the bare base name | `test_orca_ship_spawn_passes_the_base_branch_only_when_set` |
| spawn ignores a failed base fetch | `test_orca_spawn_refuses_an_unfetchable_base_branch` |
| spawn ignores the registered prefix | `test_orca_ship_spawn_names_the_branch_at_create` |
| brief reverts to a plain `git checkout -b` | `test_ship_first_action_is_idempotent_on_the_branch` |
| brief drops the Orca sentence | `test_ship_setup_states_the_orca_branch_case` |
| teardown restores a detach and `git branch -D` | `test_forced_unlanded_ship_teardown_keeps_the_branch` |

One early mutant of the teardown (detach, then `branch -D` of the already-detached HEAD) survived because it was wrong, not because the test was weak: it deleted nothing.
It was rewritten to capture the branch before detaching and was killed.

## Acceptance coverage

US1 by A1 to A4 and A9, US2 by A5 and A6, US3 by A7, FR-006 by lab step F (`passed=26 findings=0` for the firstmate level, `passed=61 findings=3` for the whole lab, the three findings unchanged from earlier slices).
Suites re-run green after the final change: `fm-brief`, `fm-spawn-orca-worktree`, `fm-backend-orca`, `fm-dod-lib`, `fm-spawn-pool-base-freshen`, `fm-task-delivery`, `fm-tangle-guard`, `fm-control-relaunch`, `fm-teardown`, `fm-teardown-endpoint-safety`, `fm-backend-orca-lab-guard`, `fm-spawn-batch`, and `bin/fm-test-run.sh --check-coverage`.

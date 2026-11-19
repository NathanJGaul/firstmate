# Cycle Log: Orca Branch At Create

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

Run from an export of the starting commit `1ccee8e5`, before any edit.

- `bin/fm-test-run.sh tests/fm-spawn-orca-worktree.test.sh` -> rc=0 (22 s)
- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` -> rc=0 (182 s)
- `bin/fm-test-run.sh tests/fm-brief.test.sh` -> rc=1: `a ref-format-valid metacharacter prefix should scaffold safely`
- full profile suite: not run here, left to CI

Method notes:

- The `fm-brief` baseline failure is an environment artifact, not a defect: this worker's `TMPDIR` lies under a dot-directory (`~/.cache/...`), so the test's marker path inside the branch prefix has a component starting with `.`, which `git check-ref-format` rightly refuses.
  Every run below sets `TMPDIR=/tmp`, which makes the same suite green on the starting commit's code path.
- None of the suites has a per-test selector, so each red was observed by running only the named function through a scratch copy that sources the same file with its bare call lines replaced, against the unchanged `bin/`; the wrapper is not committed.
- Source files were not edited while a suite was running: bash reads a script lazily, so an edit under a running `fm-spawn.sh` produced a spurious failure in one early run, which was discarded and re-run.

## Cycle 1: adapter arguments, spawn, brief, teardown (U1, U2, A1 to A7)

- tests (new): `test_worktree_create_passes_branch_and_base` (U1), `test_worktree_create_without_branch_is_unchanged` (U2), `test_forced_unlanded_ship_teardown_keeps_the_branch` (A7) in `tests/fm-backend-orca.test.sh`; `test_ship_teardown_completes_when_orca_keeps_the_branch` strengthened (A7); `test_orca_ship_spawn_names_the_branch_at_create` (A1), `test_orca_ship_spawn_passes_the_base_branch_only_when_set` (A2), `test_orca_scout_spawn_passes_no_branch` (A3), `test_orca_spawn_refuses_a_renamed_branch` (A4) in `tests/fm-spawn-orca-worktree.test.sh` (its fake `orca` now honors `--branch`, `--base-branch`, and a suffixing mode, as the real runtime does); `test_ship_first_action_is_idempotent_on_the_branch` (A5), `test_ship_setup_states_the_orca_branch_case` (A6) in `tests/fm-brief.test.sh`
- red against the unchanged code:
  - U1 `not ok - worktree create should pass --branch and --base-branch after --name` (the logged call ended `--name fm-task --no-parent --setup skip --json`)
  - U2 `not ok - worktree create with only a branch should omit --base-branch`
  - A1 `not ok - a default-prefix ship should create on fm/<id> (missing: '--branch fm/orca-branch-default-a1 ')`
  - A2 `not ok - the task base branch should reach worktree create (missing: '--base-branch release/1 ')`
  - A3 passed on the unchanged code: a characterization that a scout passes no branch, kept so a later change cannot start naming one
  - A4 `not ok - a worktree on another branch than requested should be refused`
  - A5 `not ok - the local-only first action failed on a worktree already on fm/brief-first-action-local-only` (`git checkout -b` refuses an existing branch)
  - A6 `not ok - the ship setup does not tell a worker its Orca worktree starts on the ship branch`
  - A7 `not ok - teardown must leave the branch to Orca's safe delete; firstmate force-deleted fm/orcakeepbranchz1 itself` and `not ok - a forced teardown of an unlanded ship must keep fm/orcaforcekeepz2; only Orca's safe delete may remove a branch`
- green after: `bin/backends/orca.sh` (optional branch and base arguments), `bin/fm-spawn.sh` (pass them, read the branch back), `bin/fm-brief.sh` (idempotent first action, Orca sentence), `bin/fm-teardown.sh` (Orca arm no longer detaches or runs `git branch -D`)
- existing assertions adapted, not weakened: five `assert_grep` calls in `tests/fm-brief.test.sh` matched `` `git checkout -b <branch> --` `` including the opening backtick, and now match `git checkout -b <branch> --` followed by the closing backtick, because the command is now the tail of the idempotent one-liner; the command-extraction regex in `test_branch_prefix_command_is_shell_safe` now accepts any wording before the command and still evaluates it against a ref with shell metacharacters.

## Cycle 2: the live lab found two gaps the fixtures did not (A8, FR-002, FR-009)

- test (new): lab step F assertions in `tests/fm-backend-orca-smoke.test.sh` for the spawned branch, a custom prefix, a forced unlanded teardown, and an origin-only base branch
- red, observed live on Orca 1.4.261 in the isolated lab: the origin-only base failed with `Command failed: git ... worktree add --no-track -b fm/test-orca-live-base <path> fm-test-basebr` and `fatal: invalid reference: fm-test-basebr`, and the spawn exited with no message at all because the adapter swallowed Orca's JSON refusal.
- tests (new) in response, each seen failing first: `test_worktree_create_failure_names_orca_s_reason` (`not ok - the refusal should carry Orca's own reason, got:  (missing: 'base ref release/9 does not exist')`); in the spawn suite the base case now drops the local branch and remote-tracking ref (`not ok - an Orca ship spawn with an origin-only base branch should succeed`) and `test_orca_spawn_refuses_an_unfetchable_base_branch` (`not ok - nothing should be created for an unfetchable base (unexpected: 'worktree create')`)
- green after: the adapter prints Orca's reason on a refused create, and the spawn fetches origin's base and passes `origin/<base>`
- the lab then passed with `passed=26 findings=0` (firstmate level)

## Lab red against the unchanged code (A8)

The final lab test file was run against an export of the starting commit's `bin/` (firstmate level only, isolated runtime, pinned `HOME`):
`not ok - F: the spawned worktree is on 'fm-test-orca-live', not fm/test-orca-live`, the Orca-made branch the change removes.
Against the changed code the same file passed (`passed=26 findings=0` firstmate level; `passed=61 findings=3` whole lab).

## Final runs

After the last edit to `bin/` and `tests/`, with `TMPDIR=/tmp`: `fm-brief` (28 s), `fm-spawn-orca-worktree` (30 s), `fm-backend-orca` (115 s), `fm-dod-lib`, `fm-spawn-pool-base-freshen` (82 s), `fm-task-delivery`, `fm-tangle-guard`, `fm-control-relaunch` (98 s), `fm-teardown` (207 s), `fm-teardown-endpoint-safety`, `fm-backend-orca-lab-guard`, `fm-spawn-batch` all rc=0, and `bin/fm-test-run.sh --check-coverage` ok.

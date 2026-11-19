---
feature: 009-orca-branch-at-create
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: 1ccee8e5
updated_at: 1ccee8e5
suite_baseline: unknown
---

# Test List: Orca Branch At Create

Baseline note: the suites that exercise the changed code are run green before any edit; the profile's full suite is left to CI, so `suite_baseline` is `unknown`.
`traces` values name spec acceptance scenarios (`USn.m`) and functional requirements (`FR-nnn`).

## Outer loop: acceptance behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | A ship spawn on Orca calls `worktree create` with `--branch fm/<id>`, an explicit prefix gives `<prefix><id>`, an empty prefix gives the bare id, and the worktree is on that branch | US1.1, US1.2, FR-002 | example | DONE | `tests/fm-spawn-orca-worktree.test.sh::test_orca_ship_spawn_names_the_branch_at_create` |
| A2  | The task base is fetched from origin and passed as `--base-branch origin/<base>` when set (including a base that exists only on origin), and omitted when not | US1.3, FR-002 | example | DONE | `tests/fm-spawn-orca-worktree.test.sh::test_orca_ship_spawn_passes_the_base_branch_only_when_set` |
| A3  | A scout spawn on Orca passes neither `--branch` nor `--base-branch` | US1.4, FR-002 | example | DONE | `tests/fm-spawn-orca-worktree.test.sh::test_orca_scout_spawn_passes_no_branch` |
| A4  | A spawn whose worktree lands on another branch than requested refuses, names both, and releases the worktree | US1.5, FR-003 | example | DONE | `tests/fm-spawn-orca-worktree.test.sh::test_orca_spawn_refuses_a_renamed_branch` |
| A5  | The ship brief's first-action command creates the branch at a detached HEAD and is a no-op on the branch | US2.1, US2.2, FR-004 | example | DONE | `tests/fm-brief.test.sh::test_ship_first_action_is_idempotent_on_the_branch` |
| A6  | The ship brief's setup states the Orca case and `fm_brief_base_branches` still reads the base line | US2.3, US2.4, FR-004 | example | DONE | `tests/fm-brief.test.sh::test_ship_setup_states_the_orca_branch_case` |
| A7  | An Orca ship teardown runs no `git branch -D`, and a forced teardown of an unlanded ship leaves the branch | US3.1, US3.2, FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_ship_teardown_never_force_deletes_the_branch` |
| A8  | Live lab: the spawned branch equals the expected name, a landed ship's branch is deleted, a forced unlanded ship's branch is kept | US3.3, FR-006 | live | DONE | `tests/fm-backend-orca-smoke.test.sh` step F |

## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | `fm_backend_orca_worktree_create` with a branch and base issues exactly `worktree create --repo id:R --name N --branch B --base-branch X --no-parent --setup skip --json` | FR-001 | example | DONE | `tests/fm-backend-orca.test.sh::test_worktree_create_passes_branch_and_base` |
| U2  | With neither, the call is the unchanged argument list; with only a branch, `--base-branch` is absent | FR-001 | example | DONE | `tests/fm-backend-orca.test.sh::test_worktree_create_without_branch_is_unchanged` |
| U4  | A refused `orca worktree create` reports Orca's own reason and says which create failed | FR-009 | example | DONE | `tests/fm-backend-orca.test.sh::test_worktree_create_failure_names_orca_s_reason` |
| A9  | A base branch origin cannot supply is refused before any worktree is created | US1.3, FR-002 | example | DONE | `tests/fm-spawn-orca-worktree.test.sh::test_orca_spawn_refuses_an_unfetchable_base_branch` |
| U3  | The first-action command quotes a prefix with shell metacharacters literally | FR-004 | example | DONE | `tests/fm-brief.test.sh::test_branch_prefix_command_is_shell_safe` (existing, adapted) |

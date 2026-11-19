# Analysis: Orca Branch At Create

Spec, plan, tasks, and tests agree.

- FR-001: `fm_backend_orca_worktree_create`; U1, U2.
- FR-002: the Orca arm of `bin/fm-spawn.sh`; A1 to A3, A9.
- FR-003: the branch read-back after `validate_spawn_worktree`; A4.
- FR-004: `bin/fm-brief.sh` first action and setup sentence; A5, A6, U3.
- FR-005: the Orca arm of `bin/fm-teardown.sh`; A7.
- FR-006: lab step F; A8.
- FR-007: `docs/orca-backend.md` and `docs/verification/runtime-backends.md`.
- FR-008: no edit outside the four scripts and their docs.
- FR-009: the adapter's refused-create message; U4.

Deviations from the first plan text:

- D2 said the base branch would be passed as given; the live lab showed Orca hands it to git verbatim, so the spawn fetches origin's branch and passes `origin/<base>` (FR-002, A9).
- `bin/fm-teardown.sh` was not in the task's file list, but the Orca arm's `git branch -D` is exactly the force delete the task forbids, and a forced teardown of an unlanded ship deleted the branch, so the arm changed (FR-005).
- The adapter's create failure was silent; it now carries Orca's reason (FR-009), found only because the lab spawn failed with no message.

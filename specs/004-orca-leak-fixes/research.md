# Research: Orca Backend Leak Fixes

## Orca facts used

- Orca 1.4.261 `worktree create` returns `result.worktree` and `result.startupTerminal` with `spawned`, `handle`, `tabId`, `paneKey`, `ptyId`, `surface`, per the evaluation report's reading of the runtime response builder.
  The `result.terminal` shape is the one the adapter was written against.
- `orca terminal rename --terminal <handle> --title <text> --json` sets a terminal tab title (read from `orca terminal rename --help`, 1.4.261).
- `orca worktree rm` accepts `--force` and `--delete-branch`.
  Its help says `--force` does not force branch deletion, `--delete-branch` attempts safe deletion and retains branches whose changes Orca cannot prove merged, and a result without branch evidence does not confirm deletion.
  Older hosts keep their existing branch policy and print a warning.

## Decisions

### D1: `terminal` wins over `startupTerminal`

- Decision: when both shapes are present, adopt `result.terminal`.
- Rationale: it keeps today's behavior wherever that shape appears, so the change can only add an adoption path, never move an existing one.
- Alternatives: prefer the startup terminal, rejected because it would change a shape the adapter already handles; close the unused one, rejected because Orca returns only the startup terminal on the runtime in use, so the case is hypothetical.

### D2: `spawned: false` falls back to create

- Decision: adopt the startup terminal only when `spawned` is not `false`.
- Rationale: a handle for a terminal Orca did not start would break the harness launch, while the fallback is the proven path.

### D3: rename is best effort and runs after the path check

- Decision: a failed rename does not fail the spawn, and the rename runs only once the worktree path resolved.
- Rationale: the title is cosmetic and the terminal is already the task's, so failing would leak a worktree and a terminal over a label; running it after the path check leaves the existing path-missing cleanup sequence untouched.

### D4: rename covers both adopted shapes

- Decision: title whichever terminal worktree creation hands back.
- Rationale: one post-condition, a single terminal titled with the task name, regardless of shape.
- Alternatives: rename only the startup terminal, rejected because it leaves the older shape with an Orca-chosen title for no reason.

### D5: keep `--force`, add `--delete-branch`

- Decision: `--force --delete-branch`.
- Rationale: `--force` is the existing removal semantics and teardown's landed-work checks run first; Orca's own merged-proof is what makes branch deletion safe.
- Alternatives: delete the branch from firstmate with `git branch -D`, rejected because it would force-delete and bypass Orca's merged-proof.

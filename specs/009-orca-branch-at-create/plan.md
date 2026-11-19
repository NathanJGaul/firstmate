# Implementation Plan: Orca Branch At Create

**Branch**: `fm/firstmate-orca-branch-at-create` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-orca-branch-at-create/spec.md`

## Summary

`fm_backend_orca_worktree_create` takes an optional branch and base branch and adds `--branch` and `--base-branch` to `orca worktree create`.
`bin/fm-spawn.sh` passes them for a fresh ship, then proves the worktree is on the branch.
`bin/fm-brief.sh` makes the first-action command idempotent and states the Orca case.
The Orca arm of `bin/fm-teardown.sh` stops detaching and force-deleting.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell

**Primary Dependencies**: none new; the fake `orca` in `tests/fm-spawn-orca-worktree.test.sh` and `tests/fm-backend-orca.test.sh`, and the opt-in lab

**Testing**: extend `tests/fm-backend-orca.test.sh`, `tests/fm-spawn-orca-worktree.test.sh`, `tests/fm-brief.test.sh`, and `tests/fm-backend-orca-smoke.test.sh`; run each with `bin/fm-test-run.sh <file>`, the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1` and a pinned `HOME`

**Target Platform**: Linux and macOS

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; the call without a branch stays byte-identical; no other backend changes

## Constitution Check

The constitution carries only the TDD principle in `.specify/memory/tdd-profile.md`; every behavior below is driven by a test that failed first.

## Design

### D1: Adapter arguments

`fm_backend_orca_worktree_create <project> <name> [<branch> [<base-branch>]]` builds its argument list so `--branch <branch>` and `--base-branch <base>` follow `--name` only when non-empty.
The remaining flags (`--no-parent --setup skip --json`) and the explicit `--repo id:` are untouched.

### D2: Spawn passes and verifies

The Orca arm passes `$BRANCH` only when `KIND=ship` and `RELAUNCH=0`.
When a base branch is set it first fetches `origin`'s branch into the project's remote-tracking ref (the same refs `freshen_spawn_worktree_base` updates later) and passes `origin/<base>`, because Orca hands the ref to `git worktree add` verbatim; a failed fetch exits 1 before anything is created.
The adapter's create failure now prints Orca's JSON reason instead of swallowing it.
After `validate_spawn_worktree`, a ship's worktree must report `git symbolic-ref --short HEAD` equal to `$BRANCH`.
A mismatch (Orca renamed a taken name, or an older runtime ignored the flag) exits 1 with both names; `ORCA_ABORT_CLEANUP=1` is already set at that point, so the existing abort path releases the worktree.
`freshen_spawn_worktree_base` already resets the worktree to the fetched base; on a named branch it moves that branch, which is the intended result.

### D3: Brief

The first action becomes `[ "$(git branch --show-current)" = <branch> ] || git checkout -b <branch> --`, quoted the same way as before, so it is correct at a detached HEAD and on the branch.
The setup gains one sentence after the existing detached-HEAD sentence and its optional `Base branch:` line, so `fm_brief_base_branches` still sees its sentence directly followed by its line.
The brief is written before the backend is resolved, so the wording is backend-conditional in prose and the command is idempotent rather than backend-aware.

### D4: Teardown

The Orca arm drops the `checkout --detach` and `branch -D` and keeps the hook-file cleanup and `fm_backend_remove_worktree`.
The refusals before it are unchanged, so a branch holding unlanded work is still refused unless `--force`; and with `--force` the branch is kept by Orca's safe flag.
The non-Orca arm keeps its own detach and `branch -D` (a pooled copy is reused).

### D5: Live proof

The lab's firstmate level asserts the spawned worktree is on `fm/<id>` and that a second ship with a custom prefix is on `<prefix><id>`; the existing clean teardown asserts the branch is gone (landed), and a forced teardown of a ship holding an unmerged commit asserts the branch is kept.
The final inventory still expects only `main`, so the kept branch is deleted by exact name at the end of that step.

## Project Structure

- `bin/backends/orca.sh`, `bin/fm-spawn.sh`, `bin/fm-brief.sh`, `bin/fm-teardown.sh`
- `tests/fm-backend-orca.test.sh`, `tests/fm-spawn-orca-worktree.test.sh`, `tests/fm-brief.test.sh`, `tests/fm-backend-orca-smoke.test.sh`
- `docs/orca-backend.md`, `docs/verification/runtime-backends.md`

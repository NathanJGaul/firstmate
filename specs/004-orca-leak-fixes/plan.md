# Implementation Plan: Orca Backend Leak Fixes

**Branch**: `fm/firstmate-orca-leak-fixes` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-orca-leak-fixes/spec.md`

## Summary

Two edits to one adapter, `bin/backends/orca.sh`, each proven against the fake Orca CLI in `tests/fm-backend-orca.test.sh`.

1. Adopt the startup terminal.
   `fm_backend_orca_json_get worktree-terminal-handle` also reads `result.startupTerminal.handle` when Orca reports `spawned` as anything but `false`, and `result.terminal` still wins.
   `fm_backend_orca_worktree_create` titles the adopted terminal with `orca terminal rename`, best effort, only after the path is resolved.
   `fm-spawn.sh` already skips `terminal create` whenever the adapter returns a handle, so it needs no change.
2. Release with safe branch deletion.
   `fm_backend_orca_remove_worktree` adds `--delete-branch` beside the existing `--force`.
   Teardown and the spawn abort cleanup both reach Orca through this one function.

## Technical Context

**Language/Version**: Bash 4+ with an embedded Node snippet for JSON, as the adapter already is

**Primary Dependencies**: the `orca` CLI (1.4.261 observed), `node`; no new dependency

**Storage**: none; the adapter's stdout contract (`<id>\t<path>[\t<terminal>]`) and task metadata fields are unchanged

**Testing**: colocated fake-Orca test `tests/fm-backend-orca.test.sh`, run with `bin/fm-test-run.sh tests/fm-backend-orca.test.sh`

**Target Platform**: Linux and macOS hosts running the Orca runtime

**Project Type**: shell CLI toolkit, single project

**Performance Goals**: not applicable; one extra `terminal rename` call per spawn, one fewer `terminal create`

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; teardown's landed-work refusal and id and path checks untouched; no branch in any project is deleted by this work

**Scale/Scope**: one script, one test file, two documentation lines

## Constitution Check

`.specify/memory/constitution.md` is still the unratified template in this repo, so it carries no gate to evaluate.
The workflow's own TDD rules apply instead: every behavior change starts from a test that failed first and the failure is recorded in `tdd/cycle-log.md`.
Applying a ratified TDD principle to the constitution is a captain decision outside this slice, and no constitution edit is made here.
Result: no violation, no justified complexity.

## Project Structure

### Documentation (this feature)

```text
specs/004-orca-leak-fixes/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── tasks.md
├── checklist.md
├── analyze.md
├── converge.md
├── checklists/requirements.md
└── tdd/{test-list,cycle-log,verification}.md
```

`data-model.md` and `contracts/` are skipped: no data is stored, and the adapter's stdout contract is unchanged, so there is no new interface to document.

### Source Code (repository root)

```text
bin/backends/orca.sh                 # json_get, worktree_create, remove_worktree
tests/fm-backend-orca.test.sh        # new fixtures; release assertions updated
docs/orca-backend.md                 # spawn and release statements
docs/verification/runtime-backends.md # fake-suite coverage line only
```

**Structure Decision**: extend the existing adapter and its existing test file; no new script, runner, or wrapper.

## Design

### Terminal adoption

- `worktree-terminal-handle` precedence: `result.terminal`, then `result.startupTerminal` when `spawned !== false` and the handle is a non-empty string or number, else nothing.
- The `terminal-handle` field, used to parse `terminal create` output, is not changed, so a startup terminal can never be mistaken for a created one.
- After the path check passes, `worktree_create` calls `orca terminal rename --terminal <handle> --title <name> --json` and ignores a failure.
  The path-missing branch runs before the rename and keeps closing the adopted terminal, now including a startup terminal.
- Rename covers either adopted shape, so the single terminal is titled like the one `terminal create --title` made, whichever shape Orca returned.

### Release

- `orca worktree rm --worktree id:<id> --force --delete-branch --json`.
- `--force` stays because it is the existing dirty-worktree removal semantics; Orca documents that it does not force branch deletion, and the adapter never passes a forced branch option.
- Orca keeps any branch whose changes it cannot prove merged, and a removal that reports no branch evidence is not treated as a branch deletion, so nothing in firstmate depends on the branch being gone.

### Documentation

- `docs/orca-backend.md` states the adopted startup terminal and the branch-deleting release, qualified as proven against the fake only.
- `docs/verification/runtime-backends.md` gets no live claim; its fake-suite coverage sentence gains the new cases.

## Risks and limits

- Live proof is missing: no Linux Orca lab exists, so a single live terminal after spawn and the branch outcomes after a landed and an unlanded ship are unproven and are said so in the PR.
- Older Orca hosts print a warning for the branch option; a host that rejects an unknown option would fail the release, which teardown reports as a refusal with the records kept.
  The version and capability gate slice owns gating on host version.
- The sibling slices edit nearby lines of the same files, so expect ordinary rebase work.

# Implementation Plan: Orca Spare Terminal

**Branch**: `fm/firstmate-orca-spare-terminal` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/007-orca-spare-terminal/spec.md`

## Summary

One adapter, `bin/backends/orca.sh`, gains one read and one parser field.

1. `fm_backend_orca_json_get` gains the field `listed-terminal-handle <worktree id>`, which reads `result.terminals[]` and returns the first row that has a non-empty string handle, is not `orphaned`, is not `writable:false`, and, when it names a `worktreeId`, names the requested one.
2. `fm_backend_orca_terminal_list_adopt <worktree id>` runs `orca terminal list --worktree id:<id> --json` and prints that handle, or nothing, and never fails.
3. `fm_backend_orca_worktree_create` takes the terminal from the creation response first (unchanged), and only when that is empty asks `fm_backend_orca_terminal_list_adopt`.
   It does so before the path check, so a pathless worktree closes the adopted terminal exactly as it closes a startup terminal today.
   The title rename then applies to whichever terminal was adopted.

`bin/fm-spawn.sh` already skips `terminal create` whenever the adapter returns a third field, and teardown already closes the recorded terminal, so neither changes.

## Technical Context

**Language/Version**: Bash 4+ with an embedded Node snippet for JSON, as the adapter already is

**Primary Dependencies**: the `orca` CLI (1.4.261 observed), `node`; no new dependency

**Storage**: none; the adapter's stdout contract and task metadata fields are unchanged

**Testing**: colocated fake-Orca test `tests/fm-backend-orca.test.sh`; the opt-in live lab `tests/fm-backend-orca-smoke.test.sh`

**Target Platform**: Linux and macOS hosts running the Orca runtime

**Project Type**: shell CLI toolkit, single project

**Performance Goals**: one extra `terminal list` call per spawn only when the response names no terminal; one fewer `terminal create` in that case

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; no terminal that the adapter did not create or adopt for the new worktree is touched; the lab runs only against its own isolated runtime

**Scale/Scope**: one script, one fake-Orca test file plus the lab, two documentation edits

## Constitution Check

`.specify/memory/constitution.md` carries no ratified gate that this change violates.
The workflow's own TDD rules apply: every behavior starts from a test that failed first, recorded in `tdd/cycle-log.md`.
Result: no violation, no justified complexity.

## Project Structure

```text
specs/007-orca-spare-terminal/
├── spec.md  plan.md  research.md  quickstart.md  tasks.md
├── checklist.md  analyze.md  converge.md
├── checklists/requirements.md
└── tdd/{test-list.md, cycle-log.md, verification.md}
```

Source and tests touched:

```text
bin/backends/orca.sh                   adapter: listed terminal adoption
tests/fm-backend-orca.test.sh          fake-Orca fixtures and cases
tests/fm-backend-orca-smoke.test.sh    live lab: hard liveTerminalCount=1 assertion
docs/orca-backend.md                   current adoption behavior
docs/verification/runtime-backends.md  terminal list shape and the lab result
```

## Design

- `listed-terminal-handle` takes the worktree id as its second argument, so the parser can refuse a row that names another worktree.
- The fake Orca answers `terminal list` from a keyed file and does not advance the numbered response counter, so existing numbered cases keep their meaning; with no keyed file it answers an empty list.
- The stdout contract `<id>\t<path>[\t<terminal>]` is unchanged, so `parse_orca_worktree_result` in `bin/fm-spawn.sh` needs no change.
- The live lab turns its spare-terminal finding into a hard assertion, `liveTerminalCount=1` after spawn, and keeps its existing final-inventory assertion for zero leftovers after teardown.

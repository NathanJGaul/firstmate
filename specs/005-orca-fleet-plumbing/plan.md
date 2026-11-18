# Implementation Plan: Orca Fleet Plumbing

**Branch**: `fm/firstmate-orca-fleet-plumbing` | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-orca-fleet-plumbing/spec.md`

## Summary

Three independent edits, each in the script that already owns the behavior and each proven against fakes.

1. **Bootstrap follows recorded backends.**
   `bin/fm-backend.sh` gains `fm_backend_fleet_required_tools <default-backend> <state-dir>`, which prints one `<tool> <backend>` line per distinct required tool: the default backend's tools first, then each other known backend recorded in `state/*.meta`, in first-seen order.
   `bin/fm-bootstrap.sh` replaces its single-backend tool list with that output, checking each tool through the owning backend's availability function, and its treehouse lease check follows the union.
2. **`ORCA_*` stays in the launch-env floor.**
   `bin/fm-spawn.sh` adds the observed Orca 1.4.261 names to the floor loop next to the `TMUX*` and `HERDR_*` names, and its header contract and `docs/configuration.md` list them.
3. **Wakes name the task.**
   `bin/fm-classify-lib.sh` gains `window_wake_name <window> [state]`, built on a small split of `window_to_task` that reports whether a task record matched.
   `bin/fm-watch.sh` and `bin/fm-push-transition-lib.sh` render stale reasons through it; the queue's routing key stays the handle.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell (no associative arrays), as the repository enforces on macOS

**Primary Dependencies**: none new; the fake `orca` CLI and fake `tmux` already used by the suites

**Storage**: none; task records, the wake queue's columns, and the allowlist format are unchanged

**Testing**: extend `tests/fm-bootstrap.test.sh`, `tests/fm-spawn-orca-worktree.test.sh`, and `tests/fm-watch-triage.test.sh`; run with `bin/fm-test-run.sh <file>`

**Target Platform**: Linux and macOS

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; byte-identical bootstrap output, launch text, and tmux wake reasons when no mixed fleet, no Orca, and no opaque handle is involved; no live Orca or registered repo is touched

**Scale/Scope**: five scripts, three test files, two documentation edits

## Constitution Check

The constitution is the unfilled template, so there are no gates to apply beyond the TDD principle in `.specify/memory/tdd-profile.md` and `specs/005-orca-fleet-plumbing/tdd/`.

## Design

### D1: Bootstrap helper lives beside the tool table

`fm_backend_required_tools` stays the single owner of one backend's set.
The new function only unions those sets over the backends in play, so adding a backend later changes one table.
It skips a recorded backend that `fm_backend_required_tools` rejects, which is how an unknown value adds nothing.
The default backend is always processed first so a home with no records prints exactly its old list, and an invalid default keeps its existing `BACKEND_INVALID` path in bootstrap.

### D2: A tool is checked through the backend that first requires it

`fm_backend_required_tool_available <backend> <tool>` has one backend-specific case (the cmux bundled CLI).
Only `cmux` requires the `cmux` tool, so de-duplicating by tool name and checking through the first requiring backend loses nothing.

### D3: The floor is an explicit name list

The floor cannot be a prefix: it expands names as `${NAME+"NAME=$NAME"}` in the destination shell, which has no portable way to enumerate names, and the allowlist format forbids wildcards by design.
The Orca names are therefore listed, taken from a live Orca 1.4.261 terminal.
`CLAUDE_CODE_PLUGIN_DIRS`, which Orca injects without the prefix, is left out of this slice.

### D4: The label is a rendering, never a key

`window_wake_name` returns `fm-<id>` only when a task record resolves the handle and the handle's last `:`-component does not already start with `fm-`.
It is applied where the reason text is composed; `fm_wake_append stale "$w"` keeps the handle as the key, and `window_capture`, `window_key`, and every marker path keep using the handle.
The daemon resolves a reason's window through `window_to_task`, whose existing fallback strips an `fm-` prefix, and Orca's `window=fm-<id>` field also matches directly, so label-form reasons resolve to the same task and the same per-task markers.

### D5: Structural opacity, not a backend list

The test "the handle's last component does not start with `fm-`" covers Orca (`term_<uuid>`), Herdr (`default:w5X:p2`), Zellij, and cmux alike, and leaves tmux (`session:fm-<id>`) byte-identical, without a list that drifts when a backend is added.

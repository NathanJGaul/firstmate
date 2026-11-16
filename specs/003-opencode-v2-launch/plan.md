# Implementation Plan: OpenCode v2 Worker Launch

**Spec**: `spec.md`

## Approach

1. `bin/fm-spawn.sh` launch template: `opencode --auto --prompt "$(<encode> < brief)"`.
2. `model_flag_for_harness` stops emitting `--model` for opencode; `effort_flag_for_harness` drops the `OPENCODE_CONFIG_CONTENT` variant and records-and-omits.
3. Worktree preparation for opencode writes `.opencode/opencode.json` with `{"model": ...}` when a model resolves, excludes it, refuses a tracked file, and removes a stale untracked pin when no model resolves.
4. The generated busy-state plugin becomes a dual-entry default export: `setup(ctx)` for 2.x subscribes to `ctx.event` for `session.execution.started|succeeded|failed|interrupted` and `session.retry.scheduled`; `server()` keeps the 1.x `event` hook.
5. Update `harness-adapters/references/harness/opencode.md`, the header comment in `fm-spawn.sh`, and `docs/configuration.md` effort wording.

## Verified facts (2026-11-14, opencode 2.2.5)

- `opencode --model` exits "Unrecognized flag"; TUI flags are `--standalone --server --auto --continue --session --prompt`.
- `OPENCODE_CONFIG_CONTENT` is ignored; `.opencode/opencode.json` `model` is honored.
- A plugin without a default export carrying an id and `setup` or `effect` is rejected at load ("failed to load plugin").
- The 2.x plugin context exposes `event.subscribe()`; a single prompt emitted `session.execution.started` then `session.execution.succeeded` with `data.sessionID`, and no `session.status` or `session.idle`.

## Test stack

Bash tests under `tests/`, run by `bin/fm-test-run.sh`.
Nodes host loads the generated plugin.

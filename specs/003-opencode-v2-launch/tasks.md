# Tasks: OpenCode v2 Worker Launch

Tests precede implementation; each test must be seen failing first.

- [X] T001 [A1] Test: launch has `--auto --prompt`, no `--model`, no `OPENCODE_CONFIG_CONTENT` (`tests/fm-spawn-dispatch-profile.test.sh`).
- [X] T002 [A2,A3,A4,A5] Test: model pin file written, absent without model, effort omitted, tracked file refused (`tests/fm-spawn-dispatch-profile.test.sh`).
- [X] T003 [A6,U1] Test: a stale untracked pin follows the replacement model (seeded as a relaunch leaves it).
- [X] T004 [A7,A8,A9] Test: generated plugin loads as a v2 default export and maps execution events (`tests/fm-busy-adapter-wiring.test.sh`).
- [X] T005 [A10] Test: 1.x event hook behavior unchanged.
- [X] T006 Implement launch template, model and effort functions in `bin/fm-spawn.sh`.
- [X] T007 Implement worktree model pin.
- [X] T008 Implement dual-entry plugin.
- [X] T009 Update opencode reference, spawn header, configuration doc.
- [X] T010 Live check: v2 TUI launch in tmux resolves the model and loads the plugin.

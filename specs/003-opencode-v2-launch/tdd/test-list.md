---
feature: 003-opencode-v2-launch
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 11
suite_baseline: pending
---

# TDD Test List: OpenCode v2 Worker Launch

| id  | behavior | traces | runner | test |
| --- | -------- | ------ | ------ | ---- |
| A1  | Launch is `opencode --auto --prompt`, no `--model`, no config env | US1.1, FR-001 | `bin/fm-test-run.sh tests/fm-spawn-dispatch-profile.test.sh` | opencode launch cases |
| A2  | Resolved model lands in the worktree `.opencode/opencode.json` and is excluded | US1.2, FR-002 | same | opencode pin case |
| A3  | No model or default model writes no pin | US1.3 | same | opencode no-model case |
| A4  | Effort is recorded in meta and omitted from the launch | US1.4, FR-003 | same | opencode effort cases |
| A5  | A tracked `.opencode/opencode.json` stops the spawn | US1.5, FR-002 | same | tracked-file case |
| A6  | A stale untracked pin is replaced by the replacement model, as a relaunch leaves it | US1.6 | same | stale pin case |
| A7  | Plugin is a default export with id and setup | US2.1, FR-004 | `bin/fm-test-run.sh tests/fm-busy-adapter-wiring.test.sh` | v2 lifecycle case |
| A8  | execution started/succeeded/failed/interrupted drive busy/idle and the turn-end marker | US2.2 | same | v2 lifecycle case |
| A9  | A child session's end leaves the worker busy | US2.3 | same | v2 child case |
| A10 | retry.scheduled keeps busy; 1.x events behave as before | US2.4, US2.5 | same | existing v1 case + v2 retry |
| U1  | Stale untracked pin removed when no model resolves | US1.6 | same | stale pin case (second half) |

# TDD Cycle Log: OpenCode v2 Worker Launch

Environment: opencode 2.2.5, shellcheck 0.11.0, runner `bin/fm-test-run.sh`.

## Cycle 1 - A1, A2, A3, A4 (launch form and model pin)

- RED: `bin/fm-test-run.sh tests/fm-spawn-dispatch-profile.test.sh` failed with `not ok - opencode launch must use the v2 --auto --prompt form (missing: 'opencode --auto --prompt')`, because the launch still carried `--model` and `OPENCODE_CONFIG_CONTENT`.
- GREEN: template, `model_flag_for_harness`, `effort_flag_for_harness`, and the worktree pin in `bin/fm-spawn.sh`.

## Cycle 2 - A6, U1 (stale pin)

- RED (test fixture): the first version seeded an unexcluded stale file and the spawn refused the dirty pooled worktree; the fixture was corrected to seed the exclusion a relaunch leaves behind.
- GREEN: pin rewritten or removed by the spawn.

## Cycle 3 - A5 (tracked project file)

- RED (test fixture): committing the file only in the worktree was discarded by the pooled-worktree base refresh, so the spawn succeeded; the fixture now lands the file on the project's default branch.
- GREEN: the spawn stops with an error naming the file.

## Cycle 4 - A7 to A10 (plugin)

- Evidence of the defect before the change: real `opencode run --standalone --print-logs` on 2.2.5 reported `failed to load plugin ... Plugin must export a default definition with an id and an effect or setup function` for the v1-shaped plugin (a probe plugin and the global herdr and axi plugins), and a v2 probe plugin showed 2.2.5 emits `session.execution.started` and `session.execution.succeeded` with `data.sessionID` and no `session.status` or `session.idle`.
- The v2 test was written together with the plugin rewrite, so no separate red run of it was recorded; its strength is established by the mutants below.
- GREEN: `tests/fm-busy-adapter-wiring.test.sh` passes, including the unchanged 1.x lifecycle test now driven through `default.server()`.

## Deliberate mutants (no mutation tool is installed)

| mutant | result |
| ------ | ------ |
| remove the plugin `id` | killed: `v2 busy drive failed: plugin default export lacks an id and a setup function` |
| drop `session.execution.started` from the busy mapping | killed: `execution.started must classify 'busy opencode-plugin', got 'busy fm-spawn'` |

## Live check (T010)

Real opencode 2.2.5 TUI in tmux, launched as `opencode --auto --prompt "$(cat brief)"` in a scratch worktree holding the generated plugin and a `{"model":"opencode-go/glm-5.3"}` pin:
the footer showed `Build auto · GLM-5.3 OpenCode Go`, the prompt was auto-submitted and answered, the busy-state record went busy then idle with `source=opencode-plugin event=session-execution.succeeded`, and the turn-end marker was touched.

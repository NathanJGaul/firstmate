# OpenCode

Worker launch and busy-state facts were verified on 2026-11-14 with OpenCode 2.2.5.
Earlier facts were verified on 2026-06-11 across versions 1.15.7 through 1.17.6, with busy-queue behavior re-verified on 2026-07-20 using 1.18.4.

## Operating facts

| Fact | Value |
|---|---|
| Busy state | The Firstmate-owned plugin, latched to the worker's own session. On 2.x `session.execution.started` and `session.retry.scheduled` are active and `session.execution.succeeded`, `.failed`, and `.interrupted` are inactive; 2.x emits no `session.status` or `session.idle`. On 1.x `session.status` `busy` and `retry` are active and `idle` is inactive. |
| Exit command | `/exit`. |
| Interrupt | Double Escape; it is known to be flaky while a long shell command runs, so use `../../../bin/fm-control.sh <task-id> relaunch` for a wedged pane. |
| Skill invocation | No separate verified form beyond normal slash-command behavior; use natural language when the exact command is uncertain. |
| Resume | Relaunch with `--continue` to resume the most recent session for the current directory, then send the next instruction after the TUI is ready because `--prompt` does not auto-submit alongside `--continue`. |
| Launch | `opencode --auto --prompt "<brief>"`. `--auto` auto-approves permissions that are not explicitly denied. The 2.x TUI flags are `--standalone`, `--server`, `--auto`, `--continue`, `--session`, and `--prompt`. |
| Model flag | None on the interactive launch: 2.2.5 exits with "Unrecognized flag: --model". The spawn writes the resolved model to the task worktree's `.opencode/opencode.json` (`{"model":"<provider/model>"}`), excluded from version control; it stops rather than overwrite a tracked project file of that name. `opencode run --model` still works and is the headless way to check model resolution. |
| Effort flag | None; 2.2.5 has no known effort surface for the interactive launch, so the spawn records the effort in task metadata and omits it. `OPENCODE_CONFIG_CONTENT`, which carried the 1.x permission and effort settings, is ignored entirely by 2.x. |
| Model discovery | Run `opencode models [provider]` to list available provider/model identifiers. |
| Trust dialog | None. |
| Marker | None; OpenCode publishes no identity marker, so `../../../bin/fm-harness.sh` identifies it from process ancestry. |

## Plugin loading

OpenCode 2.x loads a plugin file only when its default export carries an `id` and a `setup` function (or an `effect`); a file with only a named `async` export fails with "failed to load plugin" and is skipped silently, so a plugin written for 1.x never runs.
The spawn-written `.opencode/plugins/fm-busy-state.js` therefore exports one default object whose `setup(ctx)` subscribes to `ctx.event.subscribe()` for 2.x and whose `server()` keeps the 1.x `event` hook.
Regression coverage is `../../../tests/fm-busy-adapter-wiring.test.sh` and `../../../tests/fm-spawn-dispatch-profile.test.sh`.
The primary-side `.opencode/plugins/fm-primary-*.js` plugins use the 1.x named-export form and are not covered by that change.

OpenCode can auto-upgrade in the background, and the running TUI can exit mid-task.
That behavior was observed live during an upgrade from 1.15.7 to 1.17.3.
If the pane shows the exit banner, use the verified resume path above.

## Busy-queued Enter

While OpenCode 1.18.4 is mid-turn, its composer accepts Enter as a "send when the turn ends" keystroke but does not clear the typed text until the turn finishes.
Without a conversion, every typed-plane send to a busy OpenCode pane falsely reports "Enter swallowed", and a daemon escalation that lands while the primary is mid-turn appears wedged.

Tmux and Herdr delegate this exception to the one `fm_composer_queued_enter_verdict` policy in `../../../bin/fm-composer-lib.sh`.
Backend-specific signals are documented in `../../../docs/tmux-backend.md` and `../../../docs/herdr-backend.md`.
Regression coverage is `../../../tests/fm-tmux-submit-busy.test.sh`, `../../../tests/fm-composer-lib.test.sh`, and `../../../tests/fm-backend-herdr.test.sh`.
The live Herdr guard is `FM_HERDR_SUBMIT_CONFIRM_LIVE=1 ../../../tests/fm-herdr-submit-confirm-live-e2e.test.sh`.

## Primary integration

The primary integration was verified on 2026-07-08 with OpenCode 1.17.6.
`.opencode/plugins/fm-primary-turnend-guard.js` listens for `session.idle`.
Throwing from `session.idle` does not block `opencode run`, so the primary adapter treats the event as passive and uses `client.session.promptAsync` to force one follow-up turn when `../../../bin/fm-turnend-guard.sh` returns 2.
The follow-up was verified in the interactive TUI.
In a home with `config/supervision-host` and no `config/supervision-host-off` the watch-arm plugin spawns the supervision host instead of `../../../bin/fm-watch-arm.sh`, with Claude's print mode as its headless engine; [`supervision-host.md`](../../../../../docs/supervision-host.md) owns the host.
`opencode run` can exit before displaying a queued follow-up, so the adapter steps aside in headless mode.
On native Windows, the operational-input adapter runs its Bash helper through `bash`; macOS and Linux invoke it directly.

The companion `.opencode/plugins/fm-primary-watch-arm.js` owns normal TUI watcher supervision, wakes it with `client.session.promptAsync`, and coordinates with the guard before a blind-turn follow-up.
The PreToolUse-equivalent watcher-arm seatbelt blocks by throwing from `tool.execute.before`.

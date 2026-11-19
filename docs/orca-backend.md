# Orca runtime backend

Orca is an experimental backend in which Orca owns both the task worktree and terminal endpoint.
It runs on macOS through the Orca app and on Linux through Orca's headless runtime.
The crewmate harness remains the agent process launched inside that endpoint.
Firstmate agents load [`firstmate-orca`](../.agents/skills/firstmate-orca/SKILL.md) before operating or recovering this backend.

## Setup

Pick Orca when you already use Orca and want Orca-managed worktrees and terminals instead of Treehouse plus a session multiplexer.
Orca is explicit-only and does not support secondmate spawns.

Prerequisites:

- The universal harness and toolchain requirements in [`configuration.md`](configuration.md#toolchain).
- On macOS: `/Applications/Orca.app` installed, running, and ready.
- On macOS: the `orca` CLI, installed with `brew install orca`.
- On Linux: Orca's headless runtime, which Firstmate requires to report ready and which needs no desktop app.
- The `orca` CLI, which Firstmate looks for on `PATH`, then in `$ORCA_CLI_BIN_DIR`, then in `~/.orca/cli/bin`.
  Orca's own terminals export `ORCA_CLI_BIN_DIR` and prepend it to `PATH`, and the Linux headless runtime writes its shim to `~/.orca/cli/bin`, so a shell outside an Orca terminal, including a primary restarted outside Orca, finds the CLI without a `PATH` edit when it is in either directory.

Select Orca with local `config/backend` containing `orca`, `FM_BACKEND=orca` for one launch, or an explicit request to Firstmate.
It is never auto-detected.

Before any spawn mutates repository state, Firstmate requires `orca status --json` to report `reachable=true` and `state="ready"`.
The first task for a project registers that repository with `orca repo add --path` when needed.
No manual repository registration is required.
A project Orca already holds as a folder, or an unregistered path that is not a git repository, is refused before any worktree is created, and the refusal names the per-task `--backend <name>` option for running that task on another backend.
Firstmate never changes the Orca registration.

On macOS the Orca app can show a task's terminal, and the headless runtime on Linux has no window, so headless operators read it with `bin/fm-peek.sh <id>`.
Routine supervision uses the recorded endpoint through `bin/fm-peek.sh <id>` and `FM_HOME=<home> bin/fm-send.sh <id> '<text>'`.
The adapter delivers Enter and Ctrl+C and does not deliver Escape or Ctrl+U today.
That is an adapter gap and not an Orca limit, because Orca's help says text sent without `--enter` is written to the terminal verbatim, so control bytes pass through.
The live lab sent Escape and Ctrl+U to a real terminal and both arrived, so the gap is only the adapter's.

## Task shape and metadata

Each task has one Orca-managed git worktree and one recorded Orca terminal.
`fm-spawn.sh` does not call Treehouse for Orca tasks.
The normal isolation and unlanded-work refusal rules still apply.

```text
backend=orca
window=fm-<id>
terminal=<orca terminal handle>
orca_worktree_id=<orca repo id>::<absolute worktree path>
worktree=<absolute Orca worktree path>
```

`window=` remains the caller-facing Firstmate alias.
`terminal=` and `orca_worktree_id=` are the backend authority used by operation and cleanup paths.
Orca returns `orca_worktree_id=` as that composite of the Orca repo id and the worktree path, and cleanup validation requires both halves rather than treating the value as a simple name.

## Current lifecycle and safety

Spawn registers the repository, creates an independent worktree, installs harness hooks, records metadata, and launches the selected harness.
The task's one terminal is the terminal Orca starts with the worktree.
Spawn adopts it from `result.terminal.handle`, or `result.startupTerminal.handle` when Orca reports that terminal as spawned.
When the creation response names neither, as on the Linux headless runtime, spawn adopts the terminal that `orca terminal list --worktree id:<id>` reports for the new worktree: the first row that has a handle, is not orphaned, is not unwritable, and is not another worktree's.
Spawn titles the adopted terminal with the task name and creates no second terminal.
A failed title does not fail the spawn.
Only when Orca names no terminal and lists none for the worktree, or the list cannot be read, does spawn create one titled terminal explicitly.
Exact command flags and response parsing are owned by `bin/backends/orca.sh` and script help.

`fm-peek.sh` reads with `orca terminal read`.
An ordinary metadata-routed `fm-send.sh` text steer becomes a durable steering-inbox record, and only its best-effort constant doorbell passes through Orca's submit machinery.
When the runtime lists the `terminal.prompt-delivery.v1` capability in `orca status --json`, that machinery is Orca's own delivery receipt: one send with the enter flag and a bounded wait for a turn to start, replayed by request id (never resent) while the receipt shows input accepted and no turn yet.
A recognized agent's started turn is delivery proof, and a plain shell or unrecognized agent, which Orca cannot observe, falls to the composer check below.
A runtime without the capability, or one whose status cannot be read, keeps the literal send and Enter loop unchanged.
A terminal the runtime reports as closed, exited, or unknown makes the send fail with a message naming it and the runtime's code, and the doorbell's ring then reports the endpoint gone so the watcher escalates it directly instead of ringing again; any other failure stays an ordinary failed send.
On the typed plane, `fm-send.sh` verifies composer clearance through the fleet-wide classifier in `bin/fm-composer-lib.sh`, retrying Enter without retyping when a slash popup first fills an argument placeholder.
The composer read is one bounded tail of the live terminal and never pages backward into scrollback, so a stale startup banner cannot compete with the bottom-anchored composer.
A bare shell row is `unknown`, not an empty agent composer, and plain-text captures degrade a glyph row carrying trailing text to `unknown` rather than a false `pending`.
Orca exposes native agent state through `orca worktree ps`, `orca terminal show`, and `orca terminal wait --for tui-idle`, and Firstmate does not use it today.
Each harness adapter's semantic lifecycle supplies worker state instead, and for Claude that is the hooks Firstmate installs.
Grok alone retains its isolated rendered-tail fallback.

Cleanup keeps all shared Firstmate safety checks.
A scout still requires its report and completed decision inventory.
A ship still refuses dirty or unlanded work.
Before release, cleanup resolves the recorded Orca worktree id and verifies its path matches the recorded worktree path.
A missing, unreadable, or mismatched identity preserves metadata and stops rather than deleting anything.
After those checks, Firstmate closes the exact terminal and releases the exact worktree with Orca's worktree command, asking it to delete the branch it named for the worktree.
Orca keeps any branch whose changes it cannot prove merged, so an unlanded branch is never lost, and Firstmate never deletes that branch or forces its deletion itself.
It never raw-deletes an Orca worktree.
A close the CLI never attempted, because `orca` is not on the path, stops cleanup with the metadata intact even under `--force`: removing those records would leave nothing on disk naming a terminal that may still be live.
Reinstall the CLI and rerun; [`verification/runtime-backends.md`](verification/runtime-backends.md) "Endpoint close" owns what this arm can and cannot prove about its own close.

## Active limits

- Orca is explicit-only.
- A ready Orca runtime is required: the app on macOS or the headless runtime on Linux.
- Secondmate spawns are unsupported.
- Firstmate gates on readiness alone and sets no version floor, although `orca --version` and the `appVersion` and capability list in `orca status --json` report a version.
- A receipt proves Orca accepted input and, for a recognized agent, that its turn started; it does not prove which agent runs in a live terminal, so `fm_backend_agent_state` stays unverified for Orca.
- The adapter reads only verified response fields: the worktree id and path, a terminal handle from `result.terminal`, the root terminal object, or a `result.startupTerminal` that Orca reports as spawned, and the `result.terminals[]` rows of `terminal list --worktree`. It rejects other response shapes.
- The branch-deleting release and the one-terminal-per-task adoption are proven live on the Linux headless runtime: after spawn, `worktree ps` reports `liveTerminalCount=1`, and teardown leaves no terminal behind; `verification/runtime-backends.md` records the lab results.
- The worktrees Orca's command line creates are linked git worktrees sharing the project's git common dir (observed on Linux with Orca 1.4.261), so the spawn-time Claude workspace-trust check in `bin/fm-claude-trust.sh` accepts them.
  That check refuses any path that is not a linked git worktree, so it could never accept a project Orca registered as a folder.

## Operating posture

These are the captain's current calls, and each holds until the capability it names lands.

- Long-running or high-value ships belong on Herdr until Orca interrupt and relaunch land.
  Orca suits scouts and short ships that are cheap to redo.
- Orca refuses `interrupt`, `exit`, and `relaunch` today, so a wedged or dead Orca worker cannot be recovered through `bin/fm-control.sh` or `bin/fm-spawn.sh --relaunch`.
  Interrupt is refused for every harness except Grok, whose Ctrl+C interrupt the adapter can send.
  [`agent-control.md`](agent-control.md) owns the reasons.
- A project Orca registered as a folder, including the firstmate repository itself, cannot host Orca work, because Orca treats a folder as a different object from a git worktree.
  Spawn refuses such a project up front, and also refuses an unregistered path that is not a git repository before running `orca repo add`.
  Run that task with the per-task `--backend` override, for example `--backend herdr`.
- Away mode and quiet mode are refused when the primary runs in an Orca terminal, because the away supervisor drives only Herdr and tmux.
  Run the primary in Herdr or tmux to use either.

## Regression entry points

```sh
tests/fm-backend-orca.test.sh
tests/fm-backend.test.sh
tests/fm-bootstrap.test.sh
tests/fm-teardown-endpoint-safety.test.sh
```

The opt-in live lab runs against a throwaway Orca runtime of its own and never the operator's: `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1 tests/fm-backend-orca-smoke.test.sh`, with its guards proven by `tests/fm-backend-orca-lab-guard.test.sh`.

[`verification/runtime-backends.md`](verification/runtime-backends.md#orca) records the macOS readiness and response-shape smoke and the Linux headless 1.4.261 observations.

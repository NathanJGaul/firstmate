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
- The `orca` CLI on the `PATH` of the shell that runs Firstmate.
  Orca's own terminals export `ORCA_CLI_BIN_DIR` and prepend it to `PATH`, so any other shell, including a primary restarted outside Orca, needs that directory added.
  On the Linux headless runtime the shim directory is `~/.orca/cli/bin`.

Select Orca with local `config/backend` containing `orca`, `FM_BACKEND=orca` for one launch, or an explicit request to Firstmate.
It is never auto-detected.

Before any spawn mutates repository state, Firstmate requires `orca status --json` to report `reachable=true` and `state="ready"`.
The first task for a project registers that repository with `orca repo add --path` when needed.
No manual repository registration is required.

On macOS the Orca app can show a task's terminal, and the headless runtime on Linux has no window, so headless operators read it with `bin/fm-peek.sh <id>`.
Routine supervision uses the recorded endpoint through `bin/fm-peek.sh <id>` and `FM_HOME=<home> bin/fm-send.sh <id> '<text>'`.
The adapter delivers Enter and Ctrl+C and does not deliver Escape or Ctrl+U today.
That is an adapter gap and not an Orca limit, because Orca's help says text sent without `--enter` is written to the terminal verbatim, so control bytes pass through.
That passthrough has not been exercised live.

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
The task's one terminal is the terminal Orca starts with the worktree: `result.terminal.handle`, or `result.startupTerminal.handle` when Orca reports that terminal as spawned.
Spawn titles the adopted terminal with the task name and creates no second terminal.
A failed title does not fail the spawn.
Only when Orca reports neither does spawn create one titled terminal explicitly.
Exact command flags and response parsing are owned by `bin/backends/orca.sh` and script help.

`fm-peek.sh` reads with `orca terminal read`.
An ordinary metadata-routed `fm-send.sh` text steer becomes a durable steering-inbox record, and only its best-effort constant doorbell passes through Orca's submit machinery.
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
- The adapter reads only verified response fields: the worktree id and path, and a terminal handle from `result.terminal`, the root terminal object, or a `result.startupTerminal` that Orca reports as spawned. It rejects other response shapes.
- The startup-terminal adoption and the branch-deleting release have been exercised against a fake Orca only; `verification/runtime-backends.md` lists what a live run must still prove.
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
  The spawn path does not check the repository kind today, so spawn that task with the per-task `--backend` override, for example `--backend herdr`.
- Away mode and quiet mode are refused when the primary runs in an Orca terminal, because the away supervisor drives only Herdr and tmux.
  Run the primary in Herdr or tmux to use either.

## Regression entry points

```sh
tests/fm-backend-orca.test.sh
tests/fm-backend.test.sh
tests/fm-bootstrap.test.sh
tests/fm-teardown-endpoint-safety.test.sh
```

[`verification/runtime-backends.md`](verification/runtime-backends.md#orca) records the macOS readiness and response-shape smoke and the Linux headless 1.4.261 observations.

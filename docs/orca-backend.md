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
The adapter delivers Enter and Ctrl+C, and delivers Escape and Ctrl+U as raw control bytes.
Orca writes text sent without `--enter` to the terminal verbatim, so one control byte through `orca terminal send --text` is one key press, and the live lab proved both bytes arrive.
Escape and Ctrl+U are gated on the runtime: the adapter reads `orca status --json` fresh before each one and sends nothing, naming the capability and the version, unless the runtime reports `terminal.ordered-input.v1`.
Orca names no capability for control-byte passthrough itself, so that is the closest marker the lab saw on a runtime where passthrough was proven; a runtime without it keeps the earlier behavior and refuses these two keys.

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
A ship's worktree is created on its ship branch, the registered branch prefix plus the task id, and from the task's base branch when one is set, so the worker starts on a branch the brief and the task record already name and Orca makes no branch of its own.
Orca hands the base ref to git as given, so spawn fetches origin's base branch first and passes `origin/<base>`; a base branch origin cannot supply is refused before anything is created, and a create Orca refuses reports Orca's own reason.
Orca gives a branch name that is already taken a numeric suffix, so spawn reads the branch back and refuses, releasing the new worktree, when it is not the requested one.
A scout makes no branch and a relaunch creates no worktree, so neither names one.
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
A terminal the runtime reports as closed, exited, or unknown makes the send fail with a message naming it and the runtime's code, and the doorbell's ring then reports the endpoint gone so the watcher escalates it directly instead of ringing again; an agent parked on a permission or trust prompt is refused by the runtime, so nothing is typed or Entered, the send fails with a message naming the prompt, and the doorbell's ring reports an ordinary failed ring that the watcher re-rings later; any other failure stays an ordinary failed send.
On the typed plane, `fm-send.sh` verifies composer clearance through the fleet-wide classifier in `bin/fm-composer-lib.sh`, retrying Enter without retyping when a slash popup first fills an argument placeholder.
The composer read is one bounded tail of the live terminal and never pages backward into scrollback, so a stale startup banner cannot compete with the bottom-anchored composer.
A bare shell row is `unknown`, not an empty agent composer, and plain-text captures degrade a glyph row carrying trailing text to `unknown` rather than a false `pending`.
Orca exposes native agent state through `orca worktree ps`, `orca terminal show`, and `orca terminal wait --for tui-idle`, and Firstmate does not use it for worker state.
The one field it reads from `terminal show` is the terminal's own presence record: the cheap endpoint-presence check, the session-start digest's `endpoint:` line, and `fm-crew-state.sh` treat a terminal as present only when Orca reports it connected and writable.
An exited shell, a closed terminal, and a handle the runtime answers `terminal_handle_stale` for read as gone, even though `terminal read` still answers successfully for the first two.
Any other answer, including a stopped runtime, an unparseable reply, or a record that contradicts itself, reads as unreadable rather than gone, so a failed read never licenses recovery.
What runs inside a present terminal is proven from the local process table, never from Orca's native agent state, which keeps reporting an exited agent as present with its last state for as long as the terminal's shell lives.
Every process an Orca terminal starts carries `ORCA_TERMINAL_HANDLE=<handle>` in its environment, so `fm_backend_agent_state` scans the process table for the exact handle, adds every descendant of a process that carries it, and classifies each process with the shared harness classifier in `bin/fm-agent-process-lib.sh`.
A verified harness reads `alive`, a terminal holding only shells reads `dead`, and anything else reads `ambiguous`, with a short settle that resamples only `ambiguous` so a prompt helper in an idle shell is not mistaken for a stranger's process.
`ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE`, or `ORCA_REMOTE_PAIRING` in the environment may point the CLI at a runtime on another host, a host with no `/proc` (macOS) has no table to read, and a handle that no local process carries means the runtime is not on this host, so each of those reads `unverified` rather than guessing.
A process table that cannot be listed, or a process that cannot be placed in the tree or classified while no harness was found, reads `unreadable`.
A process of the current user whose environment the kernel refuses to show, as `systemd --user` is on a desktop, is opaque and does not make a negative verdict unreadable.
Because `fm-control interrupt` refuses an endpoint that reads `dead`, `missing`, or `ambiguous`, as it already does on tmux and Herdr, a stand-in process that no harness classifier recognizes cannot be interrupted on Orca.
Each harness adapter's semantic lifecycle supplies worker state instead, and for Claude that is the hooks Firstmate installs.
Grok alone retains its isolated rendered-tail fallback.

Cleanup keeps all shared Firstmate safety checks.
A scout still requires its report and completed decision inventory.
A ship still refuses dirty or unlanded work.
Before release, cleanup resolves the recorded Orca worktree id and verifies its path matches the recorded worktree path.
A missing, unreadable, or mismatched identity preserves metadata and stops rather than deleting anything.
After those checks, Firstmate closes the exact terminal and releases the exact worktree with Orca's worktree command, asking it to delete the ship branch.
Orca keeps any branch whose changes it cannot prove merged, so an unlanded branch is never lost, and Firstmate never detaches the worktree, deletes that branch, or forces its deletion itself, even on a forced cleanup.
A branch Orca cannot prove merged, such as one squash-merged on the forge, therefore stays in the local repository after cleanup.
It never raw-deletes an Orca worktree.
A close the CLI never attempted, because `orca` is not on the path, stops cleanup with the metadata intact even under `--force`: removing those records would leave nothing on disk naming a terminal that may still be live.
Reinstall the CLI and rerun; [`verification/runtime-backends.md`](verification/runtime-backends.md) "Endpoint close" owns what this arm can and cannot prove about its own close.

## Reclaiming a task

`bin/fm-control.sh` `exit` and `relaunch`, and the launch owner `bin/fm-spawn.sh --relaunch`, act on an Orca task only on proof.
Closing an Orca terminal returns a receipt (`ptyKilled: true`) and takes the agent with it, and `terminal create --worktree id:<recorded id>` makes a replacement inside the same worktree in one call, so Orca reclaims by close-and-recreate rather than by reusing a pane.

| The recorded terminal reads | `exit` | `relaunch` |
| --- | --- | --- |
| `dead` (present, only shells run in it) | `already-stopped` | the existing terminal is adopted: same handle, no create, no close |
| `missing`, runtime on this host, no local process carries its handle | `endpoint-gone` | the dead terminal is closed, one fresh terminal is created by the recorded worktree id and titled for the task, and the record's `terminal=` is republished |
| `alive` | refused, naming the state and `--close-terminal` | refused the same way |
| `alive`, with `--close-terminal` | closes the terminal, takes `ptyKilled: true` as the stopped proof, confirms the terminal and its processes are gone, and reports `closed` | that close, then the reclaim above |
| `ambiguous`, `unverified`, `unreadable`, or a `missing` the runtime cannot prove | refused, naming the state | refused, naming the state, with the instructions left byte-exact |

The reclaim never touches the worktree.
The worktree, its branch, its commits, and its uncommitted changes are exactly as left, the record keeps its `orca_worktree_id=` and its stable window alias, and nothing on the path calls `worktree rm` or closes by worktree.
Exactly one terminal remains for the task: the dead one is closed first, the replacement must read present and appear in `terminal list --worktree id:<recorded id>` while the old handle does not, and a replacement that cannot be confirmed is closed again rather than left behind.
Another terminal of the same worktree is never closed or adopted.
A failure before the record is published keeps the previous record and closes only the terminal this reclaim created; a failure after it leaves the record naming the replacement, which is what the next recovery reconciles.

A repeat close of an already closed terminal still answers `ptyKilled: true` on the real runtime, so the receipt alone is never what a stop verb trusts: it re-reads the endpoint and the process table afterwards, and refuses unless the terminal reads missing and no local process carries its handle.
A runtime selected through `ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE`, or `ORCA_REMOTE_PAIRING` is never proven, because the process table says nothing about another host.
[`agent-control.md`](agent-control.md) owns the verbs, the absence proof, and what a reclaim is not.
The reclaim does not cover a real-harness turn: [`verification/runtime-backends.md`](verification/runtime-backends.md#orca) records what the lab proved and what it did not.

## Active limits

- Orca is explicit-only.
- A ready Orca runtime is required: the app on macOS or the headless runtime on Linux.
- Secondmate spawns are unsupported.
- Before any spawn mutates repository state, Firstmate reads `appVersion` and the capability list from `orca status --json` and refuses a runtime whose version is below 1.4.261, the lowest runtime proven against this adapter.
  A runtime that reports no readable version is not refused, but it reports no capability either, so nothing gated on one is enabled for it.
  A task already running is not re-checked, so only a new spawn meets the floor.
- A receipt and a present endpoint prove Orca accepted input and, for a recognized agent, that its turn started; they do not prove which process runs in a live terminal.
  `fm_backend_agent_state` proves that from the local process table only: `alive`, `dead`, or `ambiguous` on the host that runs the runtime, `missing` for an absent terminal, `unreadable` for a read that failed, and `unverified` whenever the runtime may be on another host or no local process carries the handle.
  The control plane's `exit` and `relaunch` act on that proof, as [Reclaiming a task](#reclaiming-a-task) describes; secondmate restart stays refused, because Orca spawns no secondmates.
- A harness that daemonizes away from the terminal's process tree and also cleans its environment cannot be found by the scan and would read `dead`; Firstmate's launch line keeps `ORCA_TERMINAL_HANDLE` in the launch environment and runs the harness in the shell's tree, so a worker it launched is always visible.
- The adapter reads only verified response fields: the worktree id and path, a terminal handle from `result.terminal`, the root terminal object, or a `result.startupTerminal` that Orca reports as spawned, and the `result.terminals[]` rows of `terminal list --worktree`. It rejects other response shapes.
- The branch-deleting release and the one-terminal-per-task adoption are proven live on the Linux headless runtime: after spawn, `worktree ps` reports `liveTerminalCount=1`, and teardown leaves no terminal behind; `verification/runtime-backends.md` records the lab results.
- The worktrees Orca's command line creates are linked git worktrees sharing the project's git common dir (observed on Linux with Orca 1.4.261), so the spawn-time Claude workspace-trust check in `bin/fm-claude-trust.sh` accepts them.
  That check refuses any path that is not a linked git worktree, so it could never accept a project Orca registered as a folder.

## Operating posture

These are the captain's current calls, and each holds until the capability it names lands.

- Long-running or high-value ships belong on Herdr until a real-harness smoke has run on Orca.
  The process classifier and the reclaim below have landed, but only a renamed stand-in binary has run in a lab terminal, never a real harness.
  Orca suits scouts and short ships that are cheap to redo.
- Orca delivers `interrupt` through `bin/fm-control.sh` for every harness whose interrupt is Escape or Ctrl+C, and `exit` and `relaunch` act only on proof, as [Reclaiming a task](#reclaiming-a-task) describes.
  An interrupt on Orca reports `verified=agent-alive` when the process table proves the agent still runs, and otherwise proves only that the endpoint still exists; it reports `cancel=unconfirmed` unless the harness has its own acknowledgement.
  A harness that must see its screen between interrupt presses, such as Devin, is still refused, because Orca has no verified viewport read.
  [`agent-control.md`](agent-control.md) owns the reasons.
- A project Orca registered as a folder, including the firstmate repository itself, cannot host Orca work, because Orca treats a folder as a different object from a git worktree.
  Spawn refuses such a project up front, and also refuses an unregistered path that is not a git repository before running `orca repo add`.
  Run that task with the per-task `--backend` override, for example `--backend herdr`.
- Away mode and quiet mode are refused when the primary runs in an Orca terminal, because the away supervisor drives only Herdr and tmux.
  Run the primary in Herdr or tmux to use either.

## Regression entry points

```sh
tests/fm-backend-orca.test.sh
tests/fm-control.test.sh
tests/fm-control-relaunch.test.sh
tests/fm-backend.test.sh
tests/fm-bootstrap.test.sh
tests/fm-teardown-endpoint-safety.test.sh
```

The opt-in live lab runs against a throwaway Orca runtime of its own and never the operator's: `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1 tests/fm-backend-orca-smoke.test.sh`, with its guards proven by `tests/fm-backend-orca-lab-guard.test.sh`.
The lab also pins `HOME` to an empty lab home and refuses a runtime `PATH` that reaches a real agent harness, so it cannot touch the operator's agent configuration or start a real agent; the [lab isolation record](verification/runtime-backends.md#lab-isolation-home-path-and-inherited-orca-terminal-variables) has the details.

[`verification/runtime-backends.md`](verification/runtime-backends.md#orca) records the macOS readiness and response-shape smoke and the Linux headless 1.4.261 observations.

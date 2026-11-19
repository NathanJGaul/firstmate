# Research: Orca Endpoint Presence

## Real answers (Orca 1.4.261 headless, isolated lab, 2026-11-19)

Observed with `orca terminal show|read --terminal <handle> --json` in a throwaway runtime with its own data directory and a pinned `HOME`.

| state | `terminal show` | `terminal read` | `terminal list` |
| --- | --- | --- | --- |
| live shell | `ok:true`, `connected:true`, `writable:true`, `agentWait:null`, no `exitCause` | `ok:true`, `status:"running"` | listed |
| exited shell (`exit`) | `ok:true`, `connected:false`, `writable:false`, `exitCause{kind:"exited",exitCode:0}` | `ok:true`, `status:"exited"`, empty tail | not listed |
| closed terminal | `ok:true`, `connected:false`, `writable:false`, `exitCause{kind:"operator_close"}` | `ok:true`, `status:"exited"`, empty tail | not listed |
| handle never issued, or garbage | `ok:false`, `error.code:"terminal_handle_stale"`, exit 1 | the same | not listed |

`show` carries no `status` field, so one `show` call answers all four states.
`read` also answers all four, but pulls a scrollback tail the presence check does not need.
`wait --for exit` answers `satisfied:true` for exited and closed and times out for live, but a wait is a bounded blocking call and the wrong shape for a presence read.

## Decisions

- **One `terminal show` call.** It carries the two fields the report names and the exit cause, costs no scrollback, and keeps a single process spawn per presence read (the digest runs one per task under a per-task bound).
- **`status` is a contradiction guard, not a signal.** `show` has none, so a `status` that appears must agree with the record or the answer is unreadable.
- **Only a positive runtime answer proves absence.** A stopped runtime, a missing CLI, and invalid JSON are `unreadable`, which keeps the recovery contract's rule that an unreadable read never licenses recovery.
- **`present` is also the `unverified` state for the agent verdict.** A live endpoint says nothing about the process inside it; the classifier is slice N2b.

## Alternatives considered

- **Keep `terminal read` and also check `status`.** Works for the four states, but keeps a scrollback read on the cheapest probe in the fleet and misses `connected` and `writable`.
- **`terminal list --worktree` membership.** Needs the worktree id and a list scan per read, and an exited terminal being unlisted would be inferred, not answered by the terminal itself.
- **`wait --for exit --timeout-ms`.** Blocks for its whole window on every live terminal.
- **Make `terminal_not_writable` part of `missing`.** That code comes from `send`, not from a read, so it stays in the send path from the receipts slice.

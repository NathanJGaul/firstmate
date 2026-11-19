# Research: Orca Local Process Classifier

## What the real process table showed (Orca 1.4.261 headless, isolated lab, 2026-11-19)

Observed through the lab step A14 in a throwaway runtime with its own data directory and a pinned `HOME`, on Linux.

| terminal state | processes carrying `ORCA_TERMINAL_HANDLE=<handle>` |
| --- | --- |
| fresh terminal, idle shell | one `bash` (`/usr/bin/bash --rcfile <lab data>/shell-wrappers/.../rcfile`), the PTY shell |
| a copy of `sleep` named `claude` typed into that shell | the same `bash` plus one process whose kernel name and argv[0] are `claude` |
| after SIGKILL of that process | the `bash` alone |
| after `terminal close` | `terminal show` answers `connected:false, writable:false`; the endpoint verdict is `missing` before any process is read |

- Typing the renamed binary into the shell reached the shell unchanged: Orca did not rewrite the command (the earlier lab saw it append `--plugin-dir` only to a `terminal create --command` launch).
- After the SIGKILL, `terminal show` still answered `connected:true, writable:true`, so presence alone cannot see the agent die.
  The renamed `sleep` has no hooks, so `agentIdentity` was never set and `worktree ps` listed no agent; the scout's earlier observation of a hook-reported agent staying `done` after SIGKILL is the reason native state is not used as proof either way.

## A defect the first live run found

The first version tallied every own-process `environ` read that failed as unreadable, and the live verdict for an idle shell was `unreadable`.
On this host `systemd --user` and its `(sd-pam)` helper belong to the same user and refuse an environment read with `EACCES`, which is normal on a desktop with a user session.
A refused read is therefore opaque, not unreadable: such a process is still reached through the tree when it descends from a carrier, and it is not tallied.
Reading every process's parent link from `stat` (world-readable) also means a harness below a helper whose own environment is hidden is still found.
Reads that fail for any other reason, and a process that cannot be placed in the tree, still tally as unreadable.

## Decisions

- **The process table, not Orca's native state.** `worktree ps`, `terminal show`, and `agent list|show` report the last state Orca knew, so they cannot prove an agent is gone.
- **Exact handle plus descendants.** The handle is matched as a whole environment entry, and every descendant of a carrier is included, because a launcher that re-executes a harness with a cleaned environment removes the handle from the harness itself.
  Firstmate's own launch keeps `ORCA_TERMINAL_HANDLE` through its environment allowlist (it is in the fixed floor in `bin/fm-spawn.sh`), so a launched worker carries it directly.
- **`none` is `unverified`, never `dead`.** A live local terminal always has a shell carrying the handle, so an empty answer means the runtime is not on this host or its processes are not visible.
- **A selected remote runtime is `unverified` before any read.** `ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE`, and `ORCA_REMOTE_PAIRING` are the three variables that send the CLI to a paired runtime; the adapter passes no `--environment`.
- **The shared classifier, not a new one.** `fm_agent_process_classify` wraps `fm_agent_process_classify_name` and adds the node-bundle harness rules, so Orca agrees with tmux and Herdr about what a harness is.
- **Only `other` is settled.** An idle shell transiently hosts prompt helpers; the first non-`other` sample wins, as on Herdr.
- **Control plane untouched.** `fm_control_backend_state_verified` keeps refusing Orca, so exit, relaunch, and reclaim wait for the reclaim slice.

## Alternatives considered

- **`terminal create`'s `processId` and its descendants.** It is only returned at create time and is not recorded in the task record, so a later read cannot use it.
- **`ps eww` instead of `/proc`.** It would cover macOS, but its environment output is truncated and platform dependent, so the macOS verdict stays `unverified` until it is proven there.
- **Tallying a refused environment as unreadable.** It made `dead` unreachable on a normal desktop, as the first live run showed.

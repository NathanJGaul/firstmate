# Research: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

All observations are from the opt-in lab (`tests/fm-backend-orca-smoke.test.sh`, a throwaway headless runtime on Orca 1.4.261 with its own data directory, `HOME`, and loopback port, started with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1`), on Linux, 2026-11-19.
No staged build was activated, no real harness ran, and the operator's Orca was never addressed: every `orca` call in the lab went through its pinned launcher with all `ORCA_*` variables removed.

## What the runtime answers to a close

```text
terminal close --terminal <live handle> --json
  {"ok":true,"result":{"close":{"handle":"<h>","tabId":"<tab>","ptyKilled":true}}}
terminal close --terminal <the same handle again> --json
  {"ok":true,"result":{"close":{"handle":"<h>","tabId":"<tab>","ptyKilled":true}}}
terminal close --terminal term_00000000-0000-4000-8000-000000000000 --json
  {"ok":false,"error":{"code":"terminal_handle_stale",...}}
terminal list --worktree id:<id> --json after the close
  the closed handle is gone from result.terminals[]; only live rows remain
```

- The receipt is under `result.close` and names the handle it closed.
- A repeat close of an already closed terminal answers `ptyKilled: true` as well, so the receipt cannot be read as "this call killed something".
  The stop verb therefore never trusts the receipt alone: it requires the terminal to read `missing` and no local process to carry its handle afterwards.
- A closed terminal drops out of `terminal list`, so "exactly one terminal" is read from the list of live rows.

## What a killed harness and a closed terminal look like

- A renamed `sleep` named `claude`, killed with SIGKILL, leaves the terminal present and the process classifier reading `dead`; `fm-spawn --relaunch --harness <raw>` then adopts the same terminal, and the new harness is the only process named `claude` carrying the handle.
- A closed terminal reads `missing`, no process carries its handle, `fm-control exit` reports `endpoint-gone`, and the reclaim creates one terminal whose title is `fm-<id>`.
- A running agent refused without the flag, closed with `--close-terminal`, leaves no process named `claude` and the terminal reads `missing` within the wait.
- A task's `exit` after the lab's own Ctrl+C step reads `already-stopped`: Ctrl+C ended the renamed `sleep`, which is why the older lab step that expected a live agent there changed.

## Design decisions

- **Why the close is opt-in.** The brief lists `alive` among the states that keep refusing, and a wedged agent can only be stopped by the close, so the close is an explicit flag on `exit` and `relaunch` rather than an automatic fallback after a graceful exit times out.
  The graceful exit command is not used on Orca at all: the alive state refuses before any text is typed.
- **Why the absence proof reads the process table too.** Orca's terminal processes survive a runtime restart and the same handles reappear, so a handle the runtime calls stale while a harness still carries it must not license a second agent.
- **Why a separate variable closes the reclaimed terminal on abort.** `ORCA_ABORT_CLEANUP` removes the whole worktree, which a relaunch must never do.
- **Why the lab drives `fm-spawn --relaunch --harness <raw>`.** `fm-control relaunch` accepts only verified harness names, and the lab runtime's `PATH` may not hold an executable named for a real agent, so the lab's stand-in harness is the raw command the spawn recorded; `fm-control`'s own verbs are driven with the record relabelled `claude`, as the interrupt step already does.

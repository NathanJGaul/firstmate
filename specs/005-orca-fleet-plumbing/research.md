# Research: Orca Fleet Plumbing

## Facts used

- Wake queue rows are `epoch  seq  kind  key  payload`; the key is the routing handle and the payload is the reason text (`fm_wake_append_locked`, `bin/fm-wake-lib.sh`).
- The daemon resolves a stale reason's window through `window_to_task`, and every per-window marker it keeps is keyed by task (`_stale_key`), so a label does not change its markers.
- `window_to_task` matches a handle against each record's `window=` and `terminal=`, then falls back to stripping `<session>:` and `fm-` from the text.
- Orca records `window=fm-<id>` and `terminal=term_<uuid>`; the watcher keys the window by the terminal (`fm_backend_target_of_meta`).
- A live Orca 1.4.261 terminal exports these `ORCA_` names: `ORCA_AGENT_HOOK_ENDPOINT`, `ORCA_AGENT_HOOK_ENV`, `ORCA_AGENT_HOOK_OPENCODE_TUI`, `ORCA_AGENT_HOOK_PORT`, `ORCA_AGENT_HOOK_TOKEN`, `ORCA_AGENT_HOOK_TRANSPORT`, `ORCA_AGENT_HOOK_VERSION`, `ORCA_AGENT_PANE`, `ORCA_APP_VERSION`, `ORCA_CLAUDE_AGENT_VIEW_PLUGIN_DIR`, `ORCA_CLAUDE_CONFIG_DIR`, `ORCA_CLAUDE_PROFILE_POINTER`, `ORCA_CLI_BIN_DIR`, `ORCA_CLI_COMMAND`, `ORCA_HISTFILE`, `ORCA_IMAGE_PROTOCOL`, `ORCA_OMP_FRESH_CONFIG`, `ORCA_OMP_SOURCE_AGENT_DIR`, `ORCA_OMP_STATUS_EXTENSION`, `ORCA_OPENCODE_AGENT`, `ORCA_PANE_KEY`, `ORCA_PI_SOURCE_AGENT_DIR`, `ORCA_REMOTE_VIEWER_CLIPBOARD`, `ORCA_RUNTIME_SOURCE_ID`, `ORCA_RUNTIME_SOURCE_INCARNATION`, `ORCA_RUNTIME_SOURCE_PROFILE_PATH`, `ORCA_TAB_ID`, `ORCA_TERMINAL_HANDLE`, `ORCA_USER_DATA`, `ORCA_USER_DATA_PATH`, `ORCA_VERSION`, `ORCA_WORKSPACE_ID`, `ORCA_WORKTREE_ID`.

## Decisions

### D1: Retain the whole observed set, not a hand-picked subset

A partial floor breaks quietly: the agent-view and hook names feed Orca's own busy state, the CLI names route `orca` commands, and the per-agent pointers configure the harness.
Without the allowlist the worker receives all of them, so the floor matches that.
Rejected: a subset chosen by guess, which would need re-proving per harness.

### D2: Unknown recorded backends are ignored, not reported

A record naming a backend this version lacks has no dependency set to check.
Reporting it would add a second `BACKEND_INVALID` meaning (a task's backend, not the home's configured one) with no action the operator can take at session start.
Rejected: a new diagnostic line.

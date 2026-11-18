# Contract: Launch Export and Cleanup Stop

## Launch

- Every local launch built by `bin/fm-spawn.sh` (ship, scout, local secondmate, raw command, relaunch) starts its agent with `CHROME_DEVTOOLS_AXI_SESSION=<task id>`.
- The value overrides any value in the pane or the spawning environment.
- The value is present under a present launch-environment allowlist, an absent allowlist, and a launch replayed without the pane-side exports.
- A task id for which `fm_browser_session_name` returns non-zero gets no Firstmate export, and the agent inherits whatever the pane holds.

## Cleanup

- `bin/fm-teardown.sh` runs `CHROME_DEVTOOLS_AXI_SESSION=<task id> chrome-devtools-axi stop` once per cleanup, through `fm_run_timed`.
- It runs after the leaked-process cleanup and the pipeline-spend record, and only on a cleanup that has passed every unlanded-work refusal.
- It never runs when `fm_browser_session_name` returns non-zero, and never runs when `chrome-devtools-axi` is not on `PATH`.
- A non-zero status, including a hit bound, prints a warning to standard error and leaves cleanup's outcome and exit status unchanged.
- The call always sets `CHROME_DEVTOOLS_AXI_SESSION` itself, so a value inherited from the cleanup caller can never select another session.

## Helper

- `fm_browser_session_name <id>` (in `bin/fm-pr-lib.sh`) prints the id and returns 0 when `fm_task_id_creation_valid` accepts it and it is not `default`; otherwise it prints nothing and returns 1.

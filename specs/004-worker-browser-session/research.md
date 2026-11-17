# Research: Per-Worker Browser Session

All unknowns from the plan's Technical Context are resolved here.
No `NEEDS CLARIFICATION` markers remain.

## R1 - How chrome-devtools-axi selects a session

- **Decision**: Set `CHROME_DEVTOOLS_AXI_SESSION` to the task id for the worker, and set it explicitly again for the stop.
- **Evidence**: `chrome-devtools-axi --help` (0.1.44) documents `CHROME_DEVTOOLS_AXI_SESSION` as a "Named session for concurrent isolation" with its own bridge process, port, and on-disk state, defaulting to `default`.
  `dist/src/sessions.js` resolves the name in one place for every command, including `stop`.
- **Alternatives considered**: `CHROME_DEVTOOLS_AXI_PORT` per task, rejected because it needs Firstmate to allocate ports and leaves state shared; a per-task `HOME`, rejected because it breaks every other tool.

## R2 - Which names are valid

- **Decision**: Use the task id verbatim, and skip the export and the stop for the id `default`.
- **Evidence**: The tool accepts `default` or 1 to 64 characters from `[A-Za-z0-9._-]` and rejects names made only of dots.
  Firstmate's `fm_task_id_creation_valid` already requires `[A-Za-z0-9._-]`, no leading dot, and at most 64 characters, so every creation-valid id except `default` is a valid distinct session name.
  An invalid name makes every browser command throw, so the helper must never emit one.
- **Alternatives considered**: Prefixing or hashing the id, rejected because the captain's approved plan names `<task id>` and a prefix could push a 64-character id over the limit.

## R3 - The stop command

- **Decision**: `CHROME_DEVTOOLS_AXI_SESSION=<id> chrome-devtools-axi stop`.
- **Evidence**: `stop` is a documented command.
  `stopBridge` in `dist/src/client.js` reads that session's pid file, returns false when there is none or the process is dead, and otherwise terminates the bridge and, by process group, its browser children.
  A session with no bridge is therefore a no-op, which makes stopping a legacy task's never-created session harmless.
- **Alternatives considered**: Killing processes by port or working directory, rejected because the bridge's working directory is outside the leaked-process cleanup's roots and a port kill could hit another session.

## R4 - Delivering the variable through the allowlist

- **Decision**: Export it inside the launch text, beside `FM_TASK_INBOX`.
- **Evidence**: `bin/fm-spawn.sh` already states that explicit launch assignments apply inside the filtered environment, and `tests/fm-spawn-compact-adviser-disable.test.sh` proves `FM_TASK_INBOX` and `COMPACT_ADVISER_DISABLE` survive an empty allowlist and override a contrary pane value.
  An export inside the `/bin/sh -c` command runs after `env -i`, so it needs no floor-list entry and cannot be undone by an ambient forward.
- **Alternatives considered**: Adding the name to the floor list, rejected because the floor forwards the pane's ambient value, which is exactly what must be overridden.

## R5 - Bounding and failing the stop

- **Decision**: Run the stop through `fm_run_timed` with a short bound, and warn but never fail on any non-zero status.
- **Evidence**: `bin/fm-timeout-lib.sh` is the single owner of bounded execution, is already required by `bin/fm-teardown.sh`, and reports 124 on a hit bound.
  `stopBridge` itself polls about two seconds before escalating to a group kill.
- **Alternatives considered**: An unbounded call, rejected because a wedged bridge must not hold cleanup; a background stop, rejected because it would outlive cleanup and make the test unobservable.

## R6 - Where the stop runs

- **Decision**: Immediately after the leaked-process cleanup and pipeline-spend block, before the remote-job sweep and branch cleanup.
- **Evidence**: That position is after every refusal that protects unlanded work, so a refused cleanup stops nothing, and it follows the reaper as the captain's plan requires.

## R7 - Residual risks accepted

- Two session names can hash to the same port; the tool documents this as a concurrency limit.
- An operator-set `CHROME_DEVTOOLS_AXI_PORT` overrides the derived port.
- Two Firstmate homes using the same task id name the same session.
- These are recorded in the specification's assumptions and edge cases and are not addressed by this slice.

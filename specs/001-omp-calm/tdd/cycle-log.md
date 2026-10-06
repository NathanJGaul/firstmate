# Cycle Log: OMP Calm presentation

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Baseline

- suite: `bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh` -> 1 selected script, 0 failed, 1.652 seconds on 2026-10-06
- commit: `6f0f1399`
- recorded: cycle 0, before OMP feature implementation
- limitation: `bin/fm-test-run.sh --all` was started for the repository baseline but exceeded the 3600-second command bound before a final summary; the focused Calm suite is the verified TDD cycle suite.
- limitation: no single-test-by-name command, coverage tool, mutation tool, or OMP acceptance runner was verified.

## Notes and deviations

- No repository-specific TDD constitution or profile is available in this checkout; the repository's existing engineering guidance remains authoritative.
- The OMP 18.6.1 extension API has no generic user-row/transcript filter or `setWorkingVisible`; those unsupported presentation classes remain visible and are tracked as acceptance behaviors rather than hidden through semantic mutation.

## Cycle 1: A1 /calm enable

- behavior: A1 - With no preference, `/calm` enables OMP Calm, persists `on`, and emits no transcript row.
- test: `tests/fm-calm-omp-extension.test.sh` (`test_calm_command_enables_shared_preference_without_transcript_row`)
- red: `bin/fm-test-run.sh tests/fm-calm-omp-extension.test.sh` -> failed before implementation with `ERR_MODULE_NOT_FOUND` for `.omp/extensions/fm-calm.ts`.
- green: pending implementation.

## Cycle 1 green

- green: `bin/fm-test-run.sh tests/fm-calm-omp-extension.test.sh` -> A1 passed after the initial OMP factory and shared atomic preference writer were added.

## Cycle 2: A2 session restoration

- behavior: A2 - An OMP session restores active Calm before its first presentation when shared `config/calm` is `on` or legacy `max`.
- test: `tests/fm-calm-omp-extension.test.sh` (`test_calm_session_restores_shared_preference`)
- red: the focused suite failed before the lifecycle implementation with `Error: session_start was not registered`.
- green: pending implementation.

## Cycle 2 green

- green: `bin/fm-test-run.sh tests/fm-calm-omp-extension.test.sh` -> A1, A2, and U2 passed after OMP lifecycle registration and shared-sprite projection wiring.

## Cycle 3: U2 sprite projection

- behavior: U2 - The OMP working-row projection is deterministic at narrow and wide widths and advances the shared sprite without exceeding the requested width.
- test: `tests/fm-calm-omp-extension.test.sh` (`test_omp_working_ship_projection_bounds`)
- red: focused suite initially failed with `ERR_MODULE_NOT_FOUND` for `.omp/extensions/lib/fm-calm-omp-presentation.ts`.
- green: focused suite passed after the pure OMP projection helper was added.

## Cycle 4: A6 supported row adapters

- behavior: A6 - Calm hides supported legacy custom-message rows while native tools, genuine prompts, and substantive responses remain visible.
- test: `tests/fm-calm-omp-extension.test.sh` (`test_omp_supported_rows_leave_native_tools_untouched`)
- red: focused suite failed before adapter registration with `Error: legacy custom-message renderer was not registered`.
- green: focused suite passed after the legacy renderer was installed while native tools remained host-owned.

## Final focused verification

- command: `bin/fm-test-run.sh tests/fm-calm-omp-extension.test.sh tests/fm-calm-claude-mod.test.sh`
- result: 2 selected scripts, 0 failures, 3.533 seconds on 2026-10-06; OMP covered A1-A10 plus the redraw-restoration regression in 11 executable checks, while Claude covered its shared policy and operational-input regression.
- command: `bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh`
- result: pre-existing environment limitations remained (`installed @earendil-works/pi-coding-agent package not found` on compatibility cases) and the interactive run failed at `rendered export DOM violated the Calm conversation boundary`; no Pi-specific implementation fix was attempted.
- smoke: `omp/18.6.1` loaded the tracked extension in both Calm-off and Calm-on `--no-session --no-tools -p` runs; both reported only the deliberate generic-row diagnostic and exited cleanly.
- audit note: the final working-surface ownership guard and redraw-restoration regression were test-after corrections to the initial implementation; no per-cycle feature commits exist in this branch, so test-first ordering is not proven by git history.

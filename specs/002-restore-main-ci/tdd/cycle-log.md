# TDD Cycle Log: Restore Main CI

Append only. Newest last.

## Baseline

- date: 2026-10-16
- commit: `0457fccc`
- suite: not run locally in full; CI run 38557743360 on main reports 4 of 18 jobs failing (Behavior portable parallel 1, serial 5, serial 6, serial 9)
- red files reproduced individually on this machine:
  - `bin/fm-test-run.sh tests/fm-contributions.test.sh` -> `not ok - the slow head did not consume its core and parallel-wave budget`, `not ok - 1 contribution regressions`, exit 1 (about 100 seconds)
  - `bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh` (Pi 1.2.0 scratch package) -> `not ok - Pi Calm queued operational rows ... ERR_MODULE_NOT_FOUND ... fm-calm-visibility-policy.ts`, exit 1
  - `FM_LIVE=1 bin/fm-test-run.sh tests/fm-calm-pi-queue-retention-live-e2e.test.sh` -> `Failed to load extension ... Cannot find module './fm-calm-visibility-policy.ts'`, exit 1
  - `tests/fm-pi-primary-types.test.sh` with `FM_PI_PACKAGE_DIR` set to scratch Pi 1.2.0 and 1.3.0 -> `error TS2339: Property 'prompt' does not exist on type 'BeforeAgentStartEvent'` at `fm-branch-supervision.ts(1684,26)` and `fm-primary-pi-watch.ts(1203,35)`; the same file passes against Pi 1.0.4
  - `tests/fm-wake-queue.test.sh` passes locally (bash 5.3); the flake reproduced only under the fine-grained TERM-timing fuzz on bash 5.2.21: 1 failure in 931 runs, `d=0.001 rc=0 err=...fm-wake-lib.sh: trap: line 2: unexpected EOF while looking for matching ')'|WAKE_ACK_REQUIRED...`
- toolchain: Pi scratch installs 1.0.4, 1.2.0, 1.3.0 (`npm install -g --prefix`), `typescript` via the same prefix, Ubuntu 24.04 container with bash 5.2.21; machine `pi --version` is 1.3.0, machine bash is 5.3.15
- scratch locations: `/home/nathanjgaul/Projects/firstmate/data/firstmate-ci-green/pi` and `.../flake`

## Deviations recorded before the first cycle

- The loop's precondition of a green full suite does not hold, by definition of this feature: main is red in four CI jobs.
- Each cycle therefore judges green on the named failing file plus the files that exercise the touched code, run locally against Pi 1.2.0 and 1.3.0 scratch installs.
- The full suite is run by CI on the delivery pull request (success criterion SC-001).
- The branch tests were applied together because the upstream fix and its tests are one change; the red below is the first decisive failure of that combined test change against the unchanged extension.

## Cycle 1: A1, A2, U1, U2 custom-message runs (US1, branch supervision)

- tests: `tests/fm-pi-branch-extension.test.sh` (events typed `messageType: "user"`, the processing request fired as `{ messageType: "custom", message }`, and a custom-run regression with no prompt); upstream patches 8c9c67de and 5f2b81bc applied cleanly to the test files only.
- red: `bin/fm-test-run.sh tests/fm-pi-branch-extension.test.sh` against the unchanged extension -> `TypeError: Cannot read properties of undefined (reading 'trim')` at `fm-branch-supervision.ts:1686`, `not ok - the away posture must park main and present after archive`, exit 1.
- green: `.pi/extensions/fm-branch-supervision.ts` computes `processingOpenedThisRun` from the custom message, then returns unless `event.messageType === "user"` before reading `event.prompt`. `bin/fm-test-run.sh tests/fm-pi-branch-extension.test.sh` -> exit 0 (140 s).
- mutant: mirroring a custom message's content as captain dialog -> `not ok - mirror filtering, ordering, and cursor must hold ... timed out waiting for incremental mirror`, so the regression detects it; production restored from a saved copy.
- refactor: none needed; the comment above the handler was reworded to "For user messages this event is ..." to match upstream.
- commit: `d922ec8f`

## Cycle 2: A3, A4, U5, U6 primary-watch run-start handling (US1)

- tests: `tests/fm-pi-watch-extension.test.sh` user events typed with `messageType: "user"`; new tail in the replacement case: a custom run whose content equals the pending wake text must not consume it, so the follow-up replays on the next replacement.
- first run: the new tail passed against the unchanged extension (the old code read `undefined` and consumed nothing), so the deliberate-mutant check applies.
- mutant: `consumeWake(generation, event.prompt ?? event.message?.content ?? "")` -> `not ok - Pi replacement must replay a streaming follow-up before consumption: expected exit 0, got 1`; the test has teeth; production restored with `git checkout`.
- green: `.pi/extensions/fm-primary-pi-watch.ts` returns unless `event.messageType === "user"`. `bin/fm-test-run.sh tests/fm-pi-watch-extension.test.sh` -> exit 0 (65 s).
- refactor: none needed.
- commit: `d922ec8f` (same commit as cycle 1: the two extensions are one upstream change)

## Cycle 3: A5 strict typecheck on Pi 1.2.0 and 1.3.0 (US1)

- red: recorded in the baseline entry (TS2339 on both extensions against 1.2.0 and 1.3.0).
- green: `FM_PI_PACKAGE_DIR=<scratch>/p1.2.0/... bash tests/fm-pi-primary-types.test.sh` -> `ok - tracked Pi extensions pass strict no-emit typecheck against Pi 1.2.0`; the same against Pi 1.3.0.
- note: `tests/fm-pi-branch-live-e2e.test.sh` only had its two event stubs typed; the file is opt-in (`FM_PI_BRANCH_LIVE_E2E=1`) and was not run, so those two stub edits are mechanical and unexercised locally.
- commit: `d922ec8f`

## Cycle 4: U3 a custom run that is not the processing request is not aborted (US1)

- test: `tests/fm-pi-branch-extension.test.sh` fires a custom run with an unrelated custom message, then a `context` event with history, and asserts no abort.
- first run: passed against the fixed extension, so the deliberate-mutant check applies.
- mutant: `processingOpenedThisRun = event.messageType === "custom";` -> `Error: a custom run that is not the processing request was aborted as a dedicated processing turn`, exit 1; production restored from a saved copy.
- green: `bin/fm-test-run.sh tests/fm-pi-branch-extension.test.sh` -> exit 0 (72 s).
- commit: `7d770409`

## Cycle 5: A6, A7, A8, U7, U8 contributions slow-forge fixture (US2)

- test: the existing assertion `the slow head did not consume its core and parallel-wave budget` is the driving test and was not edited.
- red: recorded in the baseline entry (`not ok - the slow head did not consume ...`, exit 1).
- green: `git diff 388d56c6 7faca578 -- tests/fm-contributions.test.sh | git apply -R` restores the upstream fake-forge block. `bin/fm-test-run.sh tests/fm-contributions.test.sh` -> exit 0 (150 s; longer than the red run because the slow reads now actually take their time).
- race check (A8): a scratch copy holding the eight clock-sensitive cases ran eight-way concurrently twice -> 16 of 16 exit 0. The whole file ran three-way concurrently -> 3 of 3 exit 0.
- deviation: the whole file run eight-way concurrently failed all eight runs at `test_watcher_surfaces_new_contribution_once` (`fm-watch-checkpoint.sh --seconds 5` window) while the same file passed alone and three-way; eight whole-file runs on four cores is an overload artifact and not related to the fixture; recorded, not changed.
- refactor: none needed.
- commit: `4c33fe46`

## Cycle 6: A9, A10, U9, U10, U11 Calm fixtures hold the policy module (US3)

- tests: the existing cases are the driving tests.
- red: recorded in the baseline entry (`ERR_MODULE_NOT_FOUND ... fm-calm-visibility-policy.ts`; Pi `Cannot find module './fm-calm-visibility-policy.ts'`).
- green: `cp "$SHARED_VISIBILITY" .../fm-calm-visibility-policy.ts` added to the `queued-operational-rows` fixture and the `queued-escape` project, and the same copy added to the live guard. `bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh` -> exit 0 on Pi 1.3.0 (50 s) and on Pi 1.2.0 (46 s), no skips; `FM_LIVE=1 bin/fm-test-run.sh tests/fm-calm-pi-queue-retention-live-e2e.test.sh` -> `ok - Pi 1.3.0 exposes every queue-retention member ...` and the Pi 1.2.0 equivalent, exit 0.
- refactor: none needed; a shared copy helper is listed as follow-up.
- commit: `50587401`

## Cycle 7: U12, U13, U14 wait_for_sleep_child (US4)

- test: `test_wait_for_sleep_child_requires_a_parked_child` in `tests/fm-wake-queue.test.sh`.
- red: a harness copy of the file's header plus the case -> `wait_for_sleep_child: command not found` then `not ok - a process without children counted as parked (status 127)`.
- note: the first green attempt hung because the case left `tail -f /dev/null` and `sleep 30` orphans holding the output pipe; the case now reaps children with `pkill -P` and silences job notices.
- green: helper added to `tests/wake-helpers.sh` -> `ok - wait_for_sleep_child recognizes only a process parked in a sleep child, within a bound, without signalling it`.
- mutants: `return 0` at the top of the helper -> `not ok - a process without children counted as parked (status 0)`; matching `tail` as well as `sleep` -> `not ok - a non-sleep child counted as parked (status 0)`.
- commit: `9a9ce918`

## Cycle 8: A11, A12, U15 interrupt only a parked drain (US4)

- red: the unaided lock-and-marker predicate failed once in 931 randomized-timing runs under bash 5.2.21 (see baseline): `d=0.001 rc=0 err=...fm-wake-lib.sh: trap: line 2: unexpected EOF while looking for matching ')'`.
- green: `wait_for_sleep_child "$pid"` before `kill -TERM`, with a failure message naming the parked read boundary. The harness copy of the helper case plus the interruption case -> both ok (8 s).
- A13: the same fuzz with the fixed shape (wait for the parked child, then random 0 to 70 ms, then TERM) in the `ubuntu:24.04` container (bash 5.2.21) -> 1727 runs, 0 with a status other than 143, 0 with a trap parse error (1407 runs from the first container, which exited when its 3000-second sleep ended, plus 320 more after a restart).
- deviation: the control (old shape) ratio is the single failure in 931 recorded in the baseline; the failure window is narrow, so the control rate is a lower bound.
- commit: `9a9ce918`

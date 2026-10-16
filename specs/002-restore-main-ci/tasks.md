# Tasks: Restore Main CI

**Input**: Design documents from `specs/002-restore-main-ci/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/test-contracts.md, quickstart.md, tdd/test-list.md

Tests are mandatory.
Each test task precedes the implementation task for the same behavior, and a test must be observed failing for the right reason before its implementation task starts.
Bracketed `[U#]` and `[A#]` markers name the behavior on `tdd/test-list.md` that a task covers.
Tasks are grouped by user story; the four stories touch disjoint files, so they can proceed in any order.

## Phase 1: Setup

- [X] T001 Install scratch Pi 1.2.0 and 1.3.0 packages, `typescript`, and a bash 5.2 container outside the worktree under `/home/nathanjgaul/Projects/firstmate/data/firstmate-ci-green/pi` and `.../flake`, and record the exact versions in `specs/002-restore-main-ci/tdd/cycle-log.md`.
- [X] T002 Record the red baseline of the four failing files (`tests/fm-pi-primary-types.test.sh`, `tests/fm-contributions.test.sh`, `tests/fm-calm-pi-extension.test.sh`, `tests/fm-calm-pi-queue-retention-live-e2e.test.sh`) and the 1-in-931 interruption fuzz result in `specs/002-restore-main-ci/tdd/cycle-log.md`.

## Phase 2: User Story 1 - Pi run-start handling (Priority: P1)

**Goal**: A custom-message run neither throws nor is mirrored or consumed as a user prompt, and the Pi typecheck passes on current Pi.

**Independent Test**: `tests/fm-pi-primary-types.test.sh`, `tests/fm-pi-branch-extension.test.sh`, and `tests/fm-pi-watch-extension.test.sh` against Pi 1.2.0 and 1.3.0.

- [X] T003 [US1] [U1] [U2] [U3] Test: in `tests/fm-pi-branch-extension.test.sh` type every user-prompt `before_agent_start` event with `messageType: "user"`, fire the processing request as `{ messageType: "custom", message: processingMsg }`, and add the custom-run regression that asserts no throw and no captain-dialog mirror for a custom run with no prompt, plus a custom run whose message is not the processing request; observe it fail against the current extension.
- [X] T004 [P] [US1] [U6] Test: in `tests/fm-pi-watch-extension.test.sh` type user-prompt events with `messageType: "user"` and add a case that a custom run with no prompt consumes no pending wake and does not throw; observe it fail against the current extension.
- [X] T005 [P] [US1] [A3] Test: in `tests/fm-pi-branch-live-e2e.test.sh` type the two `sendUserMessage` event stubs with `messageType: "user"`.
- [X] T006 [US1] [U1] [U2] [U3] Implement: in `.pi/extensions/fm-branch-supervision.ts` compute `processingOpenedThisRun` from a custom event carrying the queued processing message, then return unless `event.messageType === "user"` before reading `event.prompt`.
- [X] T007 [P] [US1] [U6] Implement: in `.pi/extensions/fm-primary-pi-watch.ts` return unless `event.messageType === "user"` before `consumeWake(generation, event.prompt)`.
- [X] T008 [US1] [A5] Verify `tests/fm-pi-primary-types.test.sh` passes against Pi 1.2.0 and 1.3.0 and that the three Pi extension test files pass.

## Phase 3: User Story 2 - Contributions slow-forge fixture (Priority: P1)

**Goal**: The slow-head budget case sees a slow forge and the shared clock stays race-free.

**Independent Test**: `tests/fm-contributions.test.sh`.

- [X] T009 [US2] [U7] Test: the existing assertion `the slow head did not consume its core and parallel-wave budget` in `tests/fm-contributions.test.sh` is the driving test and is not edited; observe it fail (recorded in T002).
- [X] T010 [US2] [U7] [U8] Implement: in `tests/fm-contributions.test.sh` restore the `gh` wrapper block of `wrap_forge` to the upstream version at commit 388d56c6 (`clock_bump` published by rename, single-caller `reserve:'api repos/o/r/issues/9'`, the two `slow-wave` cases, `exhaust`, `fail-late`).
- [X] T011 [US2] [A7] [A8] Verify the file passes, then run it eight times concurrently to check the shared-clock race stays closed.

## Phase 4: User Story 3 - Calm fixtures complete (Priority: P1)

**Goal**: Every Calm fixture and the live guard can load the Pi visibility module.

**Independent Test**: `tests/fm-calm-pi-extension.test.sh` and `tests/fm-calm-pi-queue-retention-live-e2e.test.sh` against Pi 1.2.0 and 1.3.0.

- [X] T012 [US3] [U9] [U10] [U11] Test: the existing cases are the driving tests; observe `tests/fm-calm-pi-extension.test.sh` and `tests/fm-calm-pi-queue-retention-live-e2e.test.sh` fail on the missing `fm-calm-visibility-policy.ts` module (recorded in T002).
- [X] T013 [US3] [U9] [U10] Implement: in `tests/fm-calm-pi-extension.test.sh` add `cp "$SHARED_VISIBILITY" .../fm-calm-visibility-policy.ts` beside the unpaired `cp "$VISIBILITY"` in the `queued-operational-rows` fixture and the `queued-escape` project.
- [X] T014 [P] [US3] [U11] Implement: in `tests/fm-calm-pi-queue-retention-live-e2e.test.sh` copy `$ROOT/.claude/mods/firstmate-calm/lib/fm-calm-visibility.ts` to `$PROJECT/.pi/extensions/lib/fm-calm-visibility-policy.ts`.
- [X] T015 [US3] [A9] [A10] Run both files against Pi 1.2.0 and 1.3.0; fix or record any case the module error was hiding.

## Phase 5: User Story 4 - Deterministic drain interruption (Priority: P2)

**Goal**: The interruption case signals the drain only while it is parked at its delay.

**Independent Test**: `tests/fm-wake-queue.test.sh` plus the 1500-run randomized-timing fuzz under bash 5.2.21.

- [X] T016 [US4] [U12] [U13] [U14] Test: add `test_wait_for_sleep_child_requires_a_parked_child` to `tests/fm-wake-queue.test.sh` that asserts `wait_for_sleep_child` fails for a process with no sleep child within its tries, ignores a non-sleep child, succeeds once the process runs `sleep`, and never signals it; observe it fail because the helper does not exist.
- [X] T017 [US4] [U12] [U13] [U14] Implement: add `wait_for_sleep_child <pid> [tries]` to `tests/wake-helpers.sh` (poll `ps -A -o ppid= -o comm=` every 0.05 seconds for a child whose basename is `sleep`).
- [X] T018 [US4] [U15] Implement: in `test_interruption_before_and_after_raw_commit` of `tests/fm-wake-queue.test.sh` also wait with `wait_for_sleep_child "$pid"` before `kill -TERM`, keeping the bounded wait and a failure message that names the serialized read boundary.
- [X] T019 [US4] [A13] Verify: run the randomized-timing fuzz 1500 times in the bash 5.2 container against the changed test shape and record zero unexpected successes.

## Phase 6: Polish

- [ ] T020 Run `bin/fm-lint.sh`, `bin/fm-test-run.sh --check-coverage`, and `bin/fm-doc-audience-check.sh`; fix findings.
- [ ] T021 Run each named failing test file once more against Pi 1.3.0 and record the results in `specs/002-restore-main-ci/tdd/verification.md`.

## Phase 7: Acceptance gates

Each task is complete only when the named outer-loop behavior is green through its real entry point.

- [X] T022 [A1] `tests/fm-pi-branch-extension.test.sh` custom-run case is green.
- [X] T023 [A2] `tests/fm-pi-branch-extension.test.sh` processing-request-as-custom case is green.
- [X] T024 [A3] User-prompt cases in `tests/fm-pi-branch-extension.test.sh`, `tests/fm-pi-watch-extension.test.sh`, and `tests/fm-pi-branch-live-e2e.test.sh` are green.
- [X] T025 [A4] `tests/fm-pi-watch-extension.test.sh` custom-run case is green.
- [X] T026 [A5] `tests/fm-pi-primary-types.test.sh` is green on Pi 1.2.0 and 1.3.0.
- [X] T027 [A6] The slow-head case in `tests/fm-contributions.test.sh` is green.
- [X] T028 [A7] The remaining budget cases in `tests/fm-contributions.test.sh` are green with unchanged budgets.
- [X] T029 [A8] Eight concurrent runs of `tests/fm-contributions.test.sh` are green.
- [X] T030 [A9] `tests/fm-calm-pi-extension.test.sh` is green on Pi 1.2.0 and 1.3.0.
- [X] T031 [A10] `tests/fm-calm-pi-queue-retention-live-e2e.test.sh` is green.
- [X] T032 [A11] `test_interruption_before_and_after_raw_commit` is green.
- [X] T033 [A12] The helper case and the interruption case's bounded, named wait are green.
- [X] T034 [A13] The 1500-run fuzz shows zero unexpected successes.

## Phase 8: User Story 5 - OpenCode guard stdin (Priority: P2, added during verification)

**Goal**: A guard that exits without reading its payload does not crash the OpenCode host.

**Independent Test**: `tests/fm-pi-watch-extension.test.sh`.

- [X] T035 [US5] [U16] Test: add `test_opencode_turnend_guard_survives_a_guard_that_exits_without_reading_stdin` to `tests/fm-pi-watch-extension.test.sh`, stalling the host 300 ms between spawning the guard and writing its payload; observe it fail with `Error: write EPIPE` on the unfixed plugin (5 of 5 runs).
- [X] T036 [US5] [U16] Implement: in `.opencode/plugins/fm-primary-turnend-guard.js` add `child.stdin.on("error", () => {})` before `child.stdin.end(input)`.
- [X] T037 [US5] [A14] Verify the case passes (5 of 5) and that the originally flaky OpenCode case passes 160 of 160 runs under four-way parallel load.

## Phase 9: TDD remediation

The verdict is PASS_WITH_GAPS; no finding blocks the feature.

- [X] T038 Finding 2: record the interruption fuzz harness in `specs/002-restore-main-ci/tdd/verification.md` so the 1727-run claim can be repeated from a checkout (appendix present).
- [ ] T039 Findings 1, 3, 4, 5, 6, 7 are accepted as documented in `tdd/verification.md`: each is MED or lower, none can hide a regression of the five causes, and splitting or relocating the helper case would widen a CI-fix change; revisit only if a reviewer asks.

## Dependencies

T001 and T002 precede everything.
Within each story, test tasks precede implementation tasks and verification closes the story.
US1 through US4 are independent of each other and may run in parallel.
T020 and T021 run after all stories; Phase 7 closes the feature.

## Implementation Strategy

Deliver all four stories in one pull request, since the goal is one green run of all eighteen jobs.
If time-boxed, US1 is the MVP because it is the only runtime defect.

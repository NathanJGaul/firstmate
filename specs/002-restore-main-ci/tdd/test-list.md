---
feature: 002-restore-main-ci
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: 0457fccc
updated_at: a980664d
suite_baseline: red
---

# TDD Test List: Restore Main CI

Baseline note: the repository suite is red on main by definition of this feature (4 of 18 CI jobs, run 38557743360).
The full suite was not run locally because it takes about 15 minutes per shard on CI across 16 shards.
Each red job's failing file was reproduced individually instead, and those red outputs are the red evidence for the behaviors they drive.
Traces use `US<story>.<scenario>` for acceptance scenarios and `FR-nnn` for functional requirements in `spec.md`.

## Outer loop: acceptance behaviors

| id  | behavior                                                                                                          | traces         | kind    | runner                                                | state   | test                                                                                         |
| --- | ----------------------------------------------------------------------------------------------------------------- | -------------- | ------- | ----------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------- |
| A1  | A custom-message run with no prompt does not throw and mirrors no captain dialog                                  | US1.1, FR-001  | example | `bin/fm-test-run.sh tests/fm-pi-branch-extension.test.sh` | DONE    | `tests/fm-pi-branch-extension.test.sh` (new custom-run case)                                 |
| A2  | A custom run carrying the queued processing request still marks the run as opened by that request                | US1.2, FR-002  | example | `bin/fm-test-run.sh tests/fm-pi-branch-extension.test.sh` | DONE    | `tests/fm-pi-branch-extension.test.sh` (processing abort case, fired as a custom run)       |
| A3  | A user-prompt run stages the prompt as captain dialog and consumes a pending wake with that exact text            | US1.3, FR-001, FR-003 | example | `bin/fm-test-run.sh tests/fm-pi-watch-extension.test.sh` | DONE    | `tests/fm-pi-branch-extension.test.sh` and `tests/fm-pi-watch-extension.test.sh` existing cases with `messageType: "user"` |
| A4  | A custom-message run with no prompt consumes no pending wake and does not throw in the primary-watch extension    | US1.4, FR-003  | example | `bin/fm-test-run.sh tests/fm-pi-watch-extension.test.sh` | DONE    | `tests/fm-pi-watch-extension.test.sh` (new custom-run case)                                  |
| A5  | The strict no-emit typecheck of the tracked Pi extensions reports no error on Pi 1.2.0 and 1.3.0                  | US1.5, FR-004  | example | `bin/fm-test-run.sh tests/fm-pi-primary-types.test.sh` | DONE    | `tests/fm-pi-primary-types.test.sh`                                                          |
| A6  | With the slow-wave fault the first poll takes at least 8 seconds and starts no tail pull request without reserve  | US2.1, FR-006  | example | `bin/fm-test-run.sh tests/fm-contributions.test.sh`   | DONE    | `tests/fm-contributions.test.sh::test_unmeasured_url_does_not_starve_the_tail`               |
| A7  | The reserve, exhaust, fail-late, hang, and latency budget cases pass with their asserted budgets unchanged        | US2.2, FR-006, FR-010 | example | `bin/fm-test-run.sh tests/fm-contributions.test.sh`   | DONE    | `tests/fm-contributions.test.sh` budget cases (green today; must stay green)                 |
| A8  | Concurrent forge callers never observe a torn or lost fake clock across eight simultaneous file runs              | US2.3, FR-006  | example | eight concurrent `bin/fm-test-run.sh tests/fm-contributions.test.sh` | DONE    | recorded stress run in `tdd/cycle-log.md`                                                    |
| A9  | The Calm Pi extension test builds every fixture with the policy module and the whole file passes on Pi 1.2.0 and 1.3.0 | US3.1, FR-007 | example | `bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh` | DONE    | `tests/fm-calm-pi-extension.test.sh`                                                         |
| A10 | The queue-retention live guard loads its probe extension in Pi and reaches its assertions                         | US3.2, FR-008  | example | `FM_LIVE=1 bin/fm-test-run.sh tests/fm-calm-pi-queue-retention-live-e2e.test.sh` | DONE | `tests/fm-calm-pi-queue-retention-live-e2e.test.sh`                                          |
| A11 | An interrupted parked drain exits with the interrupted status and its durable row replays exactly once            | US4.1, FR-009  | example | `bin/fm-test-run.sh tests/fm-wake-queue.test.sh`      | DONE    | `tests/fm-wake-queue.test.sh::test_interruption_before_and_after_raw_commit`                 |
| A12 | The interruption case waits for the parked drain and, when it never parks, fails naming the serialized read boundary | US4.2, FR-009 | example | `bin/fm-test-run.sh tests/fm-wake-queue.test.sh`      | DONE    | `tests/fm-wake-queue.test.sh::test_interruption_before_and_after_raw_commit`                 |
| A13 | The interruption case shows zero unexpected successes in 1500 randomized-timing runs under bash 5.2.21            | US4.3, SC-004  | example | scratch fuzz in the `ubuntu:24.04` container          | DONE    | recorded run in `tdd/cycle-log.md` (not part of CI)                                          |
| A14 | A guard that exits without reading its payload does not crash the OpenCode host and the blind-turn prompt is still delivered | US5.1, FR-012 | example | `bin/fm-test-run.sh tests/fm-pi-watch-extension.test.sh` | DONE | `tests/fm-pi-watch-extension.test.sh::test_opencode_turnend_guard_survives_a_guard_that_exits_without_reading_stdin` |

## Inner loop: unit behaviors

### `.pi/extensions/fm-branch-supervision.ts`

| id  | behavior                                                                                                   | traces        | kind    | state   | test                                                         |
| --- | ---------------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | ------------------------------------------------------------ |
| U1  | A custom run with no prompt does not read a prompt and stages no captain message                           | FR-001, A1    | example | DONE    | `tests/fm-pi-branch-extension.test.sh`                       |
| U2  | A custom run whose message is the queued processing request sets the processing-opened flag                | FR-002, A2    | example | DONE    | `tests/fm-pi-branch-extension.test.sh`                       |
| U3  | A custom run whose message is not the processing request leaves the processing-opened flag unset          | FR-002        | characterization | BASELINE | `tests/fm-pi-branch-extension.test.sh` (adopted upstream behavior; first run green, mutant-verified, see cycle 4) |
| U4  | A user run whose prompt is operational or empty stages nothing                                             | FR-001        | example | DONE    | `tests/fm-pi-branch-extension.test.sh` operational-input case |

### `.pi/extensions/fm-primary-pi-watch.ts`

| id  | behavior                                                              | traces      | kind    | state   | test                                                |
| --- | --------------------------------------------------------------------- | ----------- | ------- | ------- | --------------------------------------------------- |
| U5  | A user run consumes the pending wake whose content equals the prompt  | FR-003      | example | DONE    | `tests/fm-pi-watch-extension.test.sh`               |
| U6  | A custom run consumes no pending wake                                 | FR-003, A4  | characterization | BASELINE | `tests/fm-pi-watch-extension.test.sh` (first run green against unchanged code, mutant-verified, see cycle 2) |

### `tests/fm-contributions.test.sh` (fake forge)

| id  | behavior                                                                                    | traces       | kind    | state   | test                                                                           |
| --- | ------------------------------------------------------------------------------------------- | ------------ | ------- | ------- | ------------------------------------------------------------------------------ |
| U7  | The slow-wave fault delays the pull request read by 3 seconds and its review read by 6 seconds | FR-006, A6   | example | DONE    | `tests/fm-contributions.test.sh::test_unmeasured_url_does_not_starve_the_tail` |
| U8  | The reserve fault advances the shared fake clock once per parallel wave                     | FR-006, A7   | example | DONE    | `tests/fm-contributions.test.sh::test_reservation_defers_later_url_when_fifteen_seconds_do_not_remain` |

### `tests/fm-calm-pi-extension.test.sh` and `tests/fm-calm-pi-queue-retention-live-e2e.test.sh`

| id  | behavior                                                                          | traces       | kind    | state   | test                                                                  |
| --- | --------------------------------------------------------------------------------- | ------------ | ------- | ------- | --------------------------------------------------------------------- |
| U9  | The queued-operational-rows fixture resolves the visibility module's policy import | FR-007, A9   | example | DONE    | `tests/fm-calm-pi-extension.test.sh` queued-operational-rows case     |
| U10 | The queued-escape project resolves the visibility module's policy import          | FR-007, A9   | example | DONE    | `tests/fm-calm-pi-extension.test.sh` queued-escape case               |
| U11 | The live guard's scratch project lets Pi load the probe extension                 | FR-008, A10  | example | DONE    | `tests/fm-calm-pi-queue-retention-live-e2e.test.sh`                   |

### `.opencode/plugins/fm-primary-turnend-guard.js`

| id  | behavior                                                                                  | traces       | kind    | state | test                                                                                           |
| --- | ----------------------------------------------------------------------------------------- | ------------ | ------- | ----- | ---------------------------------------------------------------------------------------------- |
| U16 | A broken pipe on the guard's stdin is ignored and the guard's exit status is still honored | FR-012, A14  | example | DONE  | `tests/fm-pi-watch-extension.test.sh::test_opencode_turnend_guard_survives_a_guard_that_exits_without_reading_stdin` |

### `tests/wake-helpers.sh` and `tests/fm-wake-queue.test.sh`

| id  | behavior                                                                                             | traces        | kind    | state   | test                                                        |
| --- | ---------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | ----------------------------------------------------------- |
| U12 | `wait_for_sleep_child` returns failure when the process has no sleep child within its bounded tries  | FR-009, A12   | example | DONE    | `tests/fm-wake-queue.test.sh::test_wait_for_sleep_child_requires_a_parked_child` |
| U13 | `wait_for_sleep_child` returns success as soon as the process runs a sleep child                     | FR-009, A12   | example | DONE    | `tests/fm-wake-queue.test.sh::test_wait_for_sleep_child_requires_a_parked_child` |
| U14 | `wait_for_sleep_child` ignores a non-sleep child and sends the process no signal                     | FR-009        | example | DONE    | `tests/fm-wake-queue.test.sh::test_wait_for_sleep_child_requires_a_parked_child` |
| U15 | The interruption case sends TERM only after the drain is parked                                      | FR-009, A11   | example | DONE    | `tests/fm-wake-queue.test.sh::test_interruption_before_and_after_raw_commit`     |

## Invariants and edge cases still to place

- FR-010 (no budget loosened, no assertion removed, no case skipped) and FR-011 (no supervision change beyond FR-001 to FR-003) are verified by reviewing the branch diff against the base, recorded in `tdd/verification.md`; they have no executable test.
- Spec edge case "a custom message that is not the processing request": covered by U3.
- Spec edge case "the wait is bounded and its failure names the boundary": covered by U12 and A12.

## Out of scope

- A pinned Pi version in CI: rejected in research R1.
- Support for Pi releases older than the run-start event split: not a supported host (spec edge cases).
- The sibling stdin writes in `.opencode/plugins/lib/fm-operational-input.js` and `.omp/extensions/fm-primary-turnend-guard.ts`: same class, not exercised by a failing test, follow-up.
- A shared helper for all fifteen visibility-module copies: follow-up, not required by any failure.
- Production changes to `bin/fm-wake-drain.sh` or `bin/fm-wake-lib.sh`: the fault is bash trap handling, avoided in the test.
- The three-case assertion that a missing fixture dependency "names the missing module": platform behavior of Node and Pi, removed from the spec.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `bin/fm-test-run.sh {file}`
- File: `bin/fm-test-run.sh {file}`
- Full suite: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`
- Coverage: `bin/fm-test-run.sh --check-coverage`
- Mutation: none installed; deliberate mutants are recorded in `tdd/verification.md`.

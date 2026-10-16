# Test Contracts: Restore Main CI

This feature exposes no new product interface.
The contracts below are the observable behaviors the tests pin.

## C1 - Run-start handling in the Pi extensions

Input: a `before_agent_start` event.
Output for a user event: unchanged from today (prompt staged as captain dialog unless operational; a pending wake with the exact text is consumed).
Output for a custom event: no throw; no captain dialog staged; no wake consumed; the processing-run flag is set only for the queued processing request.
Entry point: the extension default exports driven by `tests/fm-pi-branch-extension.test.sh` and `tests/fm-pi-watch-extension.test.sh`, and the strict typecheck `tests/fm-pi-primary-types.test.sh`.

## C2 - Fake forge fault `slow-wave`

Input: `printf 'slow-wave\n' > "$FORGE/fault"` and a poll.
Output: the first pull request read takes 3 seconds and its review read takes 6 seconds, so the first poll's elapsed time is at least 8 seconds and a tail pull request is not started without its observation reserve.
Entry point: `tests/fm-contributions.test.sh`.

## C3 - Calm fixture completeness

Input: a Calm Pi test or live guard builds a scratch project.
Output: Pi or Node can import every module of the copied extension set.
Entry point: `tests/fm-calm-pi-extension.test.sh` and `tests/fm-calm-pi-queue-retention-live-e2e.test.sh`.

## C4 - Parked-drain wait

`wait_for_sleep_child <pid> [tries]`
Returns 0 when `<pid>` has a child process whose command basename is `sleep`.
Polls every 0.05 seconds up to `tries` (default 100) and returns 1 when none appears.
It never signals the process.
Entry point: `tests/fm-wake-queue.test.sh`.

## C5 - Guard payload write

Input: a session-idle event while the guard script exits without reading stdin, with the host stalled so the write loses the race.
Output: no unhandled error; the blind-turn prompt is delivered.
Entry point: `tests/fm-pi-watch-extension.test.sh::test_opencode_turnend_guard_survives_a_guard_that_exits_without_reading_stdin`.

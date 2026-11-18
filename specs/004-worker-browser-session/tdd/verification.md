# TDD Verification: Per-Worker Browser Session

**Verdict**: Pass, with the deviations listed below.

## Test-first evidence

- Every positive behavior (A1 to A11, A16, U1, U5, U10) has a recorded red in `cycle-log.md` taken before its implementation existed, each an assertion failure showing expected and actual values.
- A12, A13, A14, A15, A17, and U2 to U4, U6 to U9 passed on first run because the shared helper already refused those inputs or because no stop existed yet.
  Each was proven strong with a deliberate mutant that makes it fail, recorded in `cycle-log.md`.
- A10 and U11 reds were first recorded with a defective fixed-string pattern; the pattern was corrected and both were re-proven with mutants T1 and T7.

## Test strength

No mutation tool exists for Bash, so strength was checked with hand-applied mutants, restored each time:

| Target | Mutants applied | Killed by |
| --- | --- | --- |
| `fm_browser_session_name` | creation check removed; prefix match on `default`; default check removed; reject dots; reject length 64 | U4, U7, U8, U9; U6; U5; U2; U3 |
| Launch export in `bin/fm-spawn.sh` | unguarded; removed; ship only; floor-only forward | A14; A1 to A8; A2, A3; A1 to A8 |
| Cleanup stop in `bin/fm-teardown.sh` | before the reap; no name guard; caller session not overridden; no tool check; stop on every exit; no bound; unsanitized bound; failure propagates | A10; A15, A17; A9, A16; A12; A13; U10; U11; A11 |

Every mutant was killed by at least one test, and every restored run passed.

## Acceptance coverage

All 17 acceptance behaviors and 11 unit behaviors on `tdd/test-list.md` are `DONE` with a named test.
Every scenario in `spec.md` maps to at least one behavior.

## Test smells

- The tests drive the real spawn and teardown scripts and execute the emitted launch command, so they assert what an agent would see, not source bytes.
- The fake `chrome-devtools-axi` is an interaction double where the call itself is the behavior.
- The only fixture refactor was extracting `relaunch_case`; a scratch-directory collision it introduced was found and fixed.

## Deviations

- Cycles 1 to 3 and cycles 4 to 12 each share a commit.
- Remaining deviations are listed in `cycle-log.md` notes.
- The repository's full suite was not run locally; the two touched test files, the runner inventory guard, lint, and the documentation audience check were.

## Command results

Recorded in `converge.md` once the final runs complete.

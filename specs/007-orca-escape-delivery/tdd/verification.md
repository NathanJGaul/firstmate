---
feature: 007-orca-escape-delivery
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 59028a30
independent: false
behaviors: 19
proven: 13
likely: 0
test_after: 0
no_test: 0
guard_green_first: 5
live_only: 1
high_smells: 0
criteria_total: 14
criteria_covered: 14
mutation_score: not measured by a tool; 10 of 10 deliberate mutants killed (scope - bin/backends/orca.sh)
mutants_survived: 0
suite: tests/fm-backend-orca.test.sh, tests/fm-control.test.sh, tests/fm-backend.test.sh, tests/fm-spawn-orca-worktree.test.sh, tests/fm-backend-orca-lab-guard.test.sh, tests/fm-documentation-audiences.test.sh, tests/fm-test-run.test.sh all pass on the final code
---

# TDD Verification: Orca Escape and Ctrl+U Delivery

## Verdict

PASS_WITH_GAPS: every behavior has a recorded red or a justified guard, and ten deliberate mutants of the adapter were all killed.
The gaps are that the audit was not independent (the same session wrote and graded the tests), no real harness turn was interrupted, and the live lane is opt-in so CI never exercises the real bytes.

## Evidence

- Test-first history: commit `59028a30` holds the tests and the specification, and the following `feat(bin)` commit holds the implementation; `tdd/cycle-log.md` records each red message.
- Guards that were green first: U6, U7, U10, A3, and A6. Each pins a "stays unchanged" or "stays refused" property; U6 is the one that held only vacuously (Escape was unsupported) and is covered by mutant M9.
- Smells: none rated high. The tests assert the exact `terminal send` argument vector through a call log and never read source bytes. U9 and U10 use several version strings in a loop, so they are example sets rather than a property tool.

## Deliberate mutants (scope: `bin/backends/orca.sh`)

Each was applied to a copy of the adapter, the ten adapter tests were run, and the file was restored byte-for-byte (`cmp`).

| id | mutation | result |
| -- | -------- | ------ |
| M1 | Escape sends `\x1c` instead of `\x1b` | killed (U2) |
| M2 | Escape sent with `--enter` | killed (U2) |
| M3 | Escape gate removed | killed (U5, U6) |
| M4 | Ctrl+U gate removed | killed (U5) |
| M5 | floor raised to 1.4.262 | killed (U9 and U10 and U8) |
| M6 | floor compares only the major part | killed (seven assertions) |
| M7 | gate keyed on `terminal.prompt-delivery.v1` | killed (U2, U3, U5) |
| M8 | an unreadable version is refused | killed (U11) |
| M9 | the gate returns success when the status is unreadable | killed (U6) |
| M10 | the capability list is not recorded | killed (U5, U8, and the sends) |

## Acceptance coverage

All fourteen criteria in the spec (the four user stories' scenarios, FR-001 to FR-012 where executable, and the edge cases) map to a test in `tdd/test-list.md`. FR-011 is documentation and is covered by `bin/fm-doc-audience-check.sh` and review.
A7 is live only: it is `tests/fm-backend-orca-smoke.test.sh`, which needs the Orca headless runtime and is opt-in.

## Gaps

- Not independent: the same session wrote and graded the tests.
- No real harness turn was interrupted; the lab proves the byte and the control path, not a harness's reaction (see `docs/verification/runtime-backends.md`).
- The capability marker is a proxy, so the gate proves "this runtime looks like the one where passthrough was proven", not "this runtime declares passthrough".

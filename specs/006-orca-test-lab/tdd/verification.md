---
feature: 006-orca-test-lab
verdict: PASS_WITH_GAPS
verified_at: 7f3f7680
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
independent: false
behaviors: 29
proven: 0
likely: 17
test_after: 0
no_test: 0
not_applicable: 12
high_findings: 0
medium_findings: 3
mutation: deliberate-mutants (no tool in profile)
---

# TDD Verification: Orca Live Test Lab

## Verdict

PASS_WITH_GAPS: every guard behavior has a recorded red and survived deliberate mutants, but the audit was not independent (the same session wrote and graded the tests), the history cannot prove test-first ordering because each cycle commits test and implementation together, and the live lane has no automated regression because it needs a real runtime.

## Evidence

The suite was run at `7f3f7680`: `bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh` passes in about 12-18 s, and `bin/fm-test-run.sh --check-coverage` exits 0 (its `comm` sort warnings predate this feature).
The baseline `tests/fm-backend-orca.test.sh` was green before the first cycle.
This audit was not independent: the author of the tests ran it, and no fresh-context subagent was used.

## Test-first evidence

| Behaviors | Class | Evidence |
| --- | --- | --- |
| A1-A3, U1-U7 | LIKELY | cycle 1 records `not ok - lane without the opt-in variable: expected exit 0, got 127`; the commit holds test and implementation together, so ordering is not provable from history |
| A4, U8, U9 | LIKELY | cycle 2 records `orca_lab_assert_own_runtime: command not found` then `not ok - A4`; one commit |
| A5, A6, U10, U11 | LIKELY | cycle 3 records `orca_lab_write_launcher: command not found` then `not ok - A5`; one commit |
| A7-A17 | NOT_APPLICABLE | live behaviors verified by a local run of the lane against its own runtime, never by a fake; the run output is kept with the task evidence |
| A18 | NOT_APPLICABLE | verified by `bin/fm-test-run.sh --check-coverage` |

No existing test was weakened, skipped, deleted, or filtered.
The only edit to existing files outside the feature is the runner's classification and weight hints in `bin/fm-test-run.sh`, the audience inventory, and two documents.
`tasks.md` ticks match the test list: every ticked behavioral task has its behavior `DONE`.

## Findings

1. MEDIUM, `tests/fm-backend-orca-lab-guard.test.sh`: the path-resolution cases cover absolute symlinks and a dangling absolute symlink only.
   `orca_lab_resolve` was checked by hand against a relative link, a chained link, a link in a parent of the candidate, and a `..` after a link, and was correct, but no committed test pins those cases, so a regression in the component-by-component resolver would pass.
2. MEDIUM, `tests/orca-lab-safety.sh` (`orca_lab_stop`): the terminal-host pid-record loop is an equivalent mutant, since the leftover pass terminates the same process.
   The loop only fixes shutdown order, and no test observes order, so the loop is untested behavior.
3. MEDIUM, `tests/fm-backend-orca-smoke.test.sh`: the live assertions (A7 to A17) have no regression coverage in the default suite, by design, because they need a real runtime.
   A shape change in a future Orca is caught only when someone opts in, which the verification record says plainly.
4. LOW, `orca_lab_validate_data_dir`: the containment arm for a candidate that contains a protected path is an equivalent mutant (such a candidate is always non-empty); it stays as defense in depth.
5. LOW, `tests/fm-backend-orca-lab-guard.test.sh`: the process cases need `/proc` and print `skip` on macOS, so the lab's process guards are Linux-verified only; the live lane is Linux-only for the same reason.

No tautological assertion, doubled subject, or re-implemented expectation was found.
The launcher case asserts what a fake node receives, not the launcher's source text.

## Mutation results

No mutation tool is in the profile, so deliberate mutants were used, one at a time, each restored and re-run green:

| Mutant | Result |
| --- | --- |
| drop the non-empty directory rule | killed (U3 root case; found and fixed a real masking defect: `/` was refused only by that rule) |
| drop the equal arm, drop the inside arm | killed (U1, U2) |
| drop the containment arm | survived, equivalent (finding 4) |
| drop the `/proc` readability refusal | killed (U8 other-owner case) |
| drop the runtime-id comparison | killed (U8 id mismatch) |
| drop the record-pid comparison | killed (U8 other pid) |
| drop the self-pid exclusion | first survived, then killed after a self-signal case was added |
| drop the `ORCA_*` unsetting loop | killed (U10; the runner's own shell carries live Orca variables, so the case is not vacuous) |
| drop the `NODE_OPTIONS` unset | killed (U10) |
| drop the leftover-kill ownership branch | killed (A6) |
| skip the terminal-host pid-record loop | survived, equivalent (finding 2) |

Eleven mutants over the library's behaviors, nine killed, two equivalent.
Sampled: all guard behaviors; none of the live lane.

## Traceability

| Criterion | Behaviors | Entry point |
| --- | --- | --- |
| US1.1 opt-in | A1 | the lane script itself |
| US1.2, US1.3 data directory | A2, A3 | the lane script with a wrong variable, and the library |
| US1.4 own runtime | A4 | library with fake processes (no real-runtime entry point is possible without Orca) |
| US1.5 launcher | A5 | the generated launcher run end to end against a fake node |
| US1.6 cleanup | A6 | library with fake processes; the live lane also asserts a zero inventory |
| US2.1-US2.9 | A7-A14 | the live lane |
| US3.1-US3.6 | A15-A17 | the live lane driving the real `fm-spawn`, `fm-peek`, `fm-send`, `fm-crew-state`, `fm-teardown` |
| US4, FR-013 | A18 | the runner's coverage check |

Every claimed test exists and runs.
FR-016 (nightly) is intentionally a documented follow-up and has no test.

## What was not audited

- Independence: not independent.
- Live lane regression strength: no mutation of the live assertions; they were exercised by running the lane, not by breaking Orca.
- macOS and any non-Linux platform.
- Performance: the guard test takes 12-18 s because of stop waits; not tuned.
- Flakiness: the guard test and the lane were each run several times without a failure, which is not a statistical measure.

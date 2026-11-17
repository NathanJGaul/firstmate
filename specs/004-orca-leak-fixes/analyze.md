# Specification Analysis: Orca Backend Leak Fixes

Cross-artifact analysis of `spec.md`, `plan.md`, and `tasks.md` against the implemented branch, run after the TDD loop, the verification, and the implementation step.
The analysis edited no artifact; the two small follow-ups it names were made afterwards, in the converge step.

## Findings

| ID | Category | Severity | Location | Summary | Recommendation |
| -- | -------- | -------- | -------- | ------- | -------------- |
| I1 | Inconsistency | MEDIUM | `spec.md` US1.2 against FR-003 and `plan.md` D4 | US1.2 says a `result.terminal` terminal is adopted "exactly as before", while FR-003 and D4 title every adopted terminal, so the older shape now also gets one `terminal rename` | Reword US1.2 to "adopted as before and titled with the task name"; the implementation and tests already follow FR-003 (`test_spawn_adopts_the_terminal_shape_and_prefers_it_over_a_startup_terminal` runs through the rename call) |
| I2 | Inconsistency | LOW | `spec.md` header | Status reads `Draft` although the feature is implemented | Set to `Implemented`, as `specs/003-opencode-v2-launch/spec.md` does |
| U1 | Underspecification | LOW | `plan.md` Source Code and Documentation lines | The plan names two documentation edits, but `docs/orca-backend.md` also had an "Active limits" bullet that the change made wrong ("only the verified terminal-handle fields are accepted"), which was corrected | Accepted as a correction of information the change made wrong; no plan edit needed |
| U2 | Underspecification | LOW | `spec.md` Assumptions, `plan.md` Risks | Older Orca hosts are assumed to warn and keep their branch policy, and a host that rejects the new option would fail the release; this rests on the 1.4.261 help text and has no test | Left to the version and capability gate slice, which the plan names; stated in the PR |
| C1 | Coverage | LOW | `spec.md` US2.2, SC-003 | "Orca keeps a branch it cannot prove merged" is Orca's behavior; the fake can only prove that firstmate completes the release when the result reports no branch deletion (A8) | Live proof waits for the Linux Orca lab; named in the spec, the docs, and the checklist |
| T1 | Task ordering | LOW | `tasks.md` Phases 3 and 4 | The file lists all of a story's tests before its implementation tasks, while the work ran one behavior at a time with the implementation interleaved | None; the order of execution is in `tdd/cycle-log.md`, and every test task precedes the implementation task that satisfies it |
| T2 | Process | HIGH (resolved) | `tasks.md` Phases 7 and 9, `tdd/verification.md` | 16 of 26 behaviors were first written green-first; the captain chose a strict redo, done as cycles 1 to 11 in `tdd/cycle-log.md`, and verification now passes | None; resolved by the redo |

No constitution conflict: `.specify/memory/constitution.md` is still the unratified template, so it carries no MUST principle to violate.
That placeholder state is repository-wide and outside this feature.

## Coverage Summary

| Requirement | Has task | Task IDs | Notes |
| ----------- | -------- | -------- | ----- |
| FR-001 adopt the startup terminal | Yes | T003, T007, T013, T025 | |
| FR-002 `terminal` shape kept and preferred | Yes | T003, T008, T013, T026 | |
| FR-003 title the adopted terminal, tolerate failure | Yes | T004, T005, T012, T014, T030 | see I1 |
| FR-004 no second terminal when adopted | Yes | T007, T008 | |
| FR-005 fallback create | Yes | T009, T010, T027, T028 | |
| FR-006 pathless result closes and releases | Yes | T006, T011, T029 | |
| FR-007 `--force --delete-branch`, never forced deletion | Yes | T016, T017, T020, T031, T033 | |
| FR-008 teardown refusals unchanged | Yes | T019, T034 | existing tests |
| FR-009 no branch deleted by the change | Yes | T024 | branch diff searched |
| SC-001 to SC-003 | Yes | T007, T009, T016 | |
| SC-004 existing tests green with only the argument change | Yes | T017, T023 | full runs recorded in `tdd/cycle-log.md` |

Unmapped tasks: T001, T002, T015, T021 to T024, T035 are setup, helper, comment, documentation, and check tasks with no behavior of their own.

## Metrics

- Requirements: 9 functional, 4 success criteria
- Tasks: 35
- Requirement coverage: 100%
- Ambiguities: 1 (I1)
- Duplications: 0
- Critical issues: 0, and one HIGH process finding (T2), resolved by the strict redo

## Next actions

Proceed to converge.
Apply I1 and I2 as two wording edits in the converge step, since they change no behavior and the analysis itself must not edit artifacts.
T2 is resolved by the strict redo.

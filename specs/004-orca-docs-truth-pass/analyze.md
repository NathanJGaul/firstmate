# Specification Analysis Report

**Feature**: Orca Documentation Truth Pass.
**Analysis mode**: Cross-artifact consistency review of `spec.md`, `plan.md`, and `tasks.md` after implementation and before convergence, read-only apart from this report.
**Constitution**: Skipped because `.specify/memory/constitution.md` is the unfilled Spec-Kit template; the TDD principle from the Spec-Kit workflow was applied as the working gate.
**Independence**: The author ran this analysis; no subagent was used.

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
| -- | -------- | -------- | ----------- | ------- | -------------- |
| I1 | Inconsistency | MEDIUM | `docs/architecture.md:265`; `bin/backends/orca.sh:4`; `bin/fm-control-lib.sh:273-275` | Three statements outside this slice's five surfaces still say what the corrected documents now deny: `docs/architecture.md` says Orca exposes "no native busy primitive at all", and the adapter header and the key-support comment attribute the missing Escape to Orca's terminal API. | Leave them to their own slices, as FR-021 and research R7 decide, and report them as follow-up for the slices that change busy-state sourcing and key delivery. Recorded in `converge.md`. |
| I2 | Inconsistency | LOW | `spec.md` FR-017; `plan.md` D5; `tasks.md` T014 | The recovery-skill line was first specified "where the Orca inventory guidance already sits" and was placed after the relaunch and reclaim guidance, beside the tmux and Herdr refusals, because that is where a refusal belongs. | `spec.md` FR-017 and `plan.md` D5 were amended to match the placement. `tasks.md` T014 is ticked and keeps its original wording, and this finding records the difference. |
| I3 | Inconsistency | LOW | `spec.md` Status | The status line still reads Draft after implementation. | Set it to Implemented when convergence is recorded. Resolved in `spec.md`. |
| I4 | Terminology | LOW | `spec.md` Key Entities; `docs/orca-backend.md` | The spec calls the captain's three calls "operating decisions" and the document heading is "Operating posture". | Accept: the spec names the entity and the document names the section, and `tasks.md` T008 uses the heading. |
| C1 | Coverage | LOW | `spec.md` SC-002; `tasks.md` | The seven-question cold read of the Orca backend document has no task of its own. | Accept: each question maps to a presence check (platforms `U1`, runtime and version `U2` and `U6`, keys `U8`, busy state `U7`, folder projects `U13`, ships `U12`, away and quiet modes `U14`), and the author re-read the finished document, recorded in `converge.md`. |
| C2 | Coverage | LOW | `spec.md` FR-020, SC-005; `tasks.md` T024 | The re-read against the evidence has no automated check by nature. | Accept: T024 is a manual task whose artifact is `data-model.md`, and `tdd/verification.md` finding 6 records it. |
| D1 | Duplication | LOW | `spec.md` FR-005 and FR-012 | Both describe the missing keys, in two documents. | Accept: two owners, each stating what its reader needs, with the one-owner rule satisfied because `docs/orca-backend.md` owns the posture and `docs/agent-control.md` points at it. |

No critical or high finding.
No placeholder, `[NEEDS CLARIFICATION]` marker, or unresolved ambiguity remains in the three artifacts.
No requirement conflicts with another: FR-013 (matrix row unchanged) and FR-012 (reason corrected) address different lines of the same file, and `U20` and `U21` pin the unchanged ones.

## Coverage Summary

| Requirement | Tasks | Notes |
| ----------- | ----- | ----- |
| FR-001, FR-002, FR-008 | T003, T004 | Covered |
| FR-003 | T003, T004 | Covered |
| FR-004 | T005, T006 | Covered |
| FR-005 | T005, T006 | Covered |
| FR-006 | T005, T006, T019, T020 | Covered |
| FR-007 | T005, T006 | Covered |
| FR-009, FR-010, FR-011 | T007, T008 | Covered |
| FR-012, FR-013 | T011, T012 | Covered |
| FR-014 | T019, T020 | Covered |
| FR-015, FR-016 | T016, T017 | Covered |
| FR-017 | T013, T014 | Covered, see I2 |
| FR-018 | T019, T021, T022 | Covered |
| FR-019 | T022 | Covered by heuristic, see `tdd/verification.md` finding 3 |
| FR-020 | T024 | Manual, see C2 |
| FR-021 | T022 | Covered by `A15` |
| SC-001 | T003 to T009 | Covered by the stale-statement checks |
| SC-002 | T003 to T008 | Covered, see C1 |
| SC-003 | T016, T017 | Covered |
| SC-004 | T021, T025 | Covered |
| SC-005 | T024 | Manual, see C2 |
| SC-006 | T011, T013, T014 | Covered |

## Unmapped Tasks

None: T001 and T002 are setup, T022 to T026 are polish and closing tasks, and every other task carries a story label.

## Metrics

- Functional requirements: 21.
- Success criteria: 6.
- User stories: 4.
- Tasks: 26.
- Coverage of requirements with at least one task: 100 percent.
- Ambiguity count: 0.
- Duplication count: 1, accepted.
- Critical issues: 0.

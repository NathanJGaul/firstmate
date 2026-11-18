# Cross-Artifact Analysis: Pin the CI Runner Image

**Feature**: `004-pin-ci-runner-image` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Tasks**: [tasks.md](tasks.md)

## Coverage

| Requirement | Plan section | Task | Evidence |
| --- | --- | --- | --- |
| FR-001 | Runner pin | T006 | `ci.yml` diff; guard green |
| FR-002 | Runner pin | T004 | red then green in `tdd/cycle-log.md` cycle 1 |
| FR-003 | Runner pin | T006 | comment above `jobs:` |
| FR-004 | Runner pin | T007 | `docs/fm-test-portable-shards.md` line 8 |
| FR-005 | Fake Pi host | T005, T008 | red then green in cycle 2 |
| FR-006 | Constraints | T009, T010 | mutants; no test removed |

Every requirement maps to a plan section, a task, and evidence; no task lacks a requirement.

## Consistency findings

- No contradiction between the spec, plan, and tasks.
- The spec's Overview lists four uutils differences; the verification record reproduces three of them in the container and the fourth (no `tsc`) from the hosted log, and the pin addresses all four at once.
- The classification table lives outside the repository on purpose (private task evidence); the spec carries only the distilled current facts, per `firstmate-coding-guidelines`.

## Residual risk

- Three failures were seen once on hosted 26.04 and not reproduced (tmux smoke window, remote lifecycle watcher bound, Herdr presentation recovery lock).
  They are named in the spec's out-of-scope list so a recurrence on the pinned image is recognizable, not hidden.
- The uutils `mkdir` race is a real product defect on 26.04 hosts and is not fixed here; it needs a lock-protocol design call.

---
feature: 006-orca-test-lab
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 24
planned_at: 48a6d07b
updated_at: 790f6c64
suite_baseline: unknown
---

# Test List: Orca Live Test Lab

Baseline note: `tests/fm-backend-orca.test.sh` and the runner coverage check are run green before any edit; the full profile suite is left to CI.
`traces` values name spec acceptance scenarios (`USn.m`), functional requirements (`FR-nnn`), and edge cases (`EC`).
The guard behaviors (A1 to A6, all U rows) run in the portable guard test with fake processes.
The live behaviors (A7 to A17) run only in the opt-in lane against the lane's own runtime; a live behavior is DONE when the lane's local run shows its line, and is never claimed from a fake.

## Outer loop: acceptance behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | With the opt-in variable unset or not `1`, the lane exits 0 printing one skip line and starts no process | US1.1, FR-001 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| A2  | A data directory equal to, inside, or containing `~/.orca` or `~/.orca-remote`, or reached through a symlink, is refused with nothing created | US1.2, FR-002 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| A3  | A caller-supplied non-empty data directory is refused; an absent or empty one is accepted | US1.3, FR-003 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| A4  | A recorded runtime whose pid, environment owner, or runtime id is not the lab's own child is refused and receives no signal | US1.4, FR-006, FR-007 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| A5  | The lab launcher runs the CLI with the lab data directory and none of the caller's other Orca variables | US1.5, FR-004, FR-005 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| A6  | Stopping the lab terminates its own processes, leaves a bystander process running, and the leftover scan reports none | US1.6, FR-007, FR-008 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| A7  | Live: status is ready and the lane reports app version, capability count, and degradations | US2.1, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A8  | Live: the repo is kind git, the folder is kind folder, and the worktree-under-folder result is reported | US2.2, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A9  | Live: a created worktree is a linked git worktree inside the lab and the terminal shape is reported | US2.3, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A10 | Live: Escape, Ctrl+U, and interrupt reach a `cat -v` shell and read status and source are reported | US2.4, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A11 | Live: agent identity and agent list are reported before and after a fake agent exits | US2.5, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A12 | Live: submit-wait and retry receipts are reported and a retried send is checked for repeated input | US2.6, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A13 | Live: removal keeps an unmerged branch and deletes a landed one, leaving no terminal, process, or directory | US2.7, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A14 | Live: a lab runtime restart is survived or not by the terminal, reported; assertion 11 is recorded not run with its reason | US2.8, US2.9, FR-009 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A15 | Live: spawn with a raw harness, peek, send text and key, and crew state work on the Orca backend | US3.1, US3.2, US3.3, FR-010 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A16 | Live: teardown refuses dirty and unlanded work, then a clean teardown removes everything | US3.4, US3.5, FR-010 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A17 | Live: the final inventory finds zero leftover terminals, processes, worktrees, and branches | US3.6, SC-002 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` |
| A18 | Both tests are classified so `bin/fm-test-run.sh --check-coverage` passes | US4, FR-013, SC-005 | example | DONE | `bin/fm-test-run.sh --check-coverage` |

## Inner loop: bin and test library behaviors

### `tests/orca-lab-safety.sh`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | Path resolution refuses a candidate equal to the protected path | FR-002 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U2  | It refuses a candidate one level inside the protected path | FR-002 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U3  | It refuses `$HOME` and `/`, which contain the protected path | FR-002 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U4  | It accepts a sibling whose name only shares a prefix with the protected path | FR-002 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U5  | It refuses a symlink whose target is the protected path | FR-002 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U6  | An empty directory and an absent path are accepted, a directory with one entry is refused | FR-003 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U7  | An unset or empty data directory variable is refused | FR-002 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U8  | The own-runtime proof refuses a missing record, a dead pid, a pid whose environment names another directory, and a runtime id mismatch | FR-006 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U9  | The signal helper refuses a pid that fails the proof and sends nothing | FR-007 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U10 | The launcher script contains no other `ORCA_` assignment than the data directory | FR-004, FR-005 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |
| U11 | The leftover scan finds a process naming the lab directory and ignores one that does not | FR-008 | example | DONE | `tests/fm-backend-orca-lab-guard.test.sh` (case of the same id) |

## Out of scope

- Adapter behavior changes (follow-ups in the pull request), the nightly workflow, and assertion 11.

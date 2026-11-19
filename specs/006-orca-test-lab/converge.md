# Convergence: Orca Live Test Lab

Assessed after the TDD loop, verification, implementation, checklist, and analysis, against the spec, plan, and tasks as the only source of intent.

## Result

One documented gap, accepted: the scheduled nightly workflow (FR-016) is a follow-up, as the task allows when it cannot be written to fail soft.
Every other functional requirement, user story scenario, and edge case is implemented and covered, and every task in `tasks.md` is done.

## Checked

- 16 functional requirements, 5 success criteria, 4 user stories, and the six edge cases, satisfied in `tests/orca-lab-safety.sh`, `tests/fm-backend-orca-lab-guard.test.sh`, `tests/fm-backend-orca-smoke.test.sh`, `bin/fm-test-run.sh`, and the verification record.
- The constitution is an unfilled template, so its checks were skipped.
- A real run of the lane on this host passed 35 hard assertions, reported 5 findings and 1 assertion not run, left no process, directory, systemd scope, worktree, or branch, and left the operator's runtime running with its data directory unchanged.

## Merge readiness and risk

- Evidence: the guard test passes, eleven deliberate mutants were run (nine killed, two equivalent), lint and the documentation audience check are clean, and the Orca regression set from report section 6.3 passes (`fm-backend-orca`, `fm-backend`, `fm-teardown-endpoint-safety`, `fm-spawn-orca-worktree`, `fm-control`, `fm-bootstrap`, `fm-project-capacity`), after one pre-existing hermeticity failure in `fm-teardown-endpoint-safety` on a host with Orca installed was fixed in its own commit.
- Risk 1: the lane's live assertions run only on request, so a future Orca shape change is caught only by an opt-in run.
- Risk 2: the lane reads the runtime's entry points from the command-line shim Orca writes; a layout change makes it fail with a message naming what is missing, not skip.
- Risk 3: the lane starts a real runtime, so a bug in the guards is the one way it could touch real state; the guards are tested without Orca and were exercised on the real runtime, and the operator's runtime data was compared before and after.

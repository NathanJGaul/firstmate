# Convergence Report: Restore Main CI

**Outcome**: Converged within the feature scope after one appended task.

## Scope checked

- `spec.md` functional requirements FR-001 through FR-012 and buildable success criteria SC-003 through SC-006.
- User stories US1 through US5 and all acceptance scenarios.
- `plan.md` design decisions R1 through R5 and the source files it names.
- `tasks.md` T001 through T041.

## Findings

| ID | Gap type | Severity | Source | Evidence | Remaining work |
| -- | -------- | -------- | ------ | -------- | -------------- |
| F1 | partial | LOW | FR-001 | `docs/pi-supervision-branch.md` described the `before_agent_start` prompt staging without saying it applies only to user-started runs | T041 (completed in this pass) |

No missing, contradicting, or unrequested work remains in the specified scope.

- FR-001 to FR-003: `.pi/extensions/fm-branch-supervision.ts` and `.pi/extensions/fm-primary-pi-watch.ts` read the prompt only when `event.messageType === "user"`; the processing request is recognized from the custom message.
- FR-004: the strict typecheck passes against Pi 1.2.0 and 1.3.0.
- FR-005: the custom-run regression cases are in `tests/fm-pi-branch-extension.test.sh` and `tests/fm-pi-watch-extension.test.sh`.
- FR-006: `tests/fm-contributions.test.sh` holds the upstream fake-forge block with the `slow-wave` cases and the rename-published clock bump.
- FR-007, FR-008: every Calm Pi fixture and the live guard copy the policy module.
- FR-009: `tests/wake-helpers.sh` provides `wait_for_sleep_child`, and the interruption case uses it.
- FR-010, FR-011: the branch diff outside `specs/` removes no assertion, adds no skip, lowers no threshold, and changes no supervision behavior beyond FR-001 to FR-003 and FR-012 (`tdd/verification.md`, "Existing-test audit").
- FR-012: `.opencode/plugins/fm-primary-turnend-guard.js` ignores a broken pipe on the guard's stdin.

## Verification evidence

- Strict Pi typecheck: ok against Pi 1.2.0 and 1.3.0.
- `tests/fm-pi-branch-extension.test.sh`, `tests/fm-calm-pi-extension.test.sh`, `tests/fm-calm-pi-queue-retention-live-e2e.test.sh`: exit 0 on both Pi releases.
- `tests/fm-pi-watch-extension.test.sh`: exit 0 on Pi 1.3.0 three times and on Pi 1.2.0 once at `a980664d`; the OpenCode case passed 160 of 160 runs under four-way parallel load (5 failures in 80 before the fix).
- `tests/fm-contributions.test.sh`: exit 0 (150 s), three-way concurrent runs 3 of 3.
- `tests/fm-wake-queue.test.sh`: exit 0 (235 s); the interruption fuzz shape shows 0 unexpected successes in 1727 runs under bash 5.2.21.
- `bin/fm-lint.sh` on every changed shell file with full dataflow (pinned ShellCheck 0.11.0): no findings; `bin/fm-lint.sh` default run also validates the three workflow files with actionlint 1.7.12.
- `LC_ALL=C bin/fm-test-run.sh --check-coverage`: ok.
- `bin/fm-doc-audience-check.sh`: ok after the new Spec-Kit documents were classified.

## Remaining delivery work

- The 18-job CI result on the delivery pull request (SC-001, SC-002) can only be observed after the pipeline pushes.
- Reviewer sign-off on `checklist.md` items CHK001 to CHK019 stays with the reviewer.

## Risk

- Residual: the bash 5.2 mechanism for the lost trap is inferred from the error text and not proven; the fix removes the exposure rather than the bash fault.
- Residual: the full repository suite was not run locally; CI is the full-suite evidence.
- Observed, out of scope, recorded as follow-up: two sibling child-process stdin writes without an error listener (`.opencode/plugins/lib/fm-operational-input.js`, `.omp/extensions/fm-primary-turnend-guard.ts`), and `bin/fm-test-run.sh --check-coverage` exiting 1 under `en_US.UTF-8` because its `comm` calls compare lists that were sorted under `LC_ALL=C`.

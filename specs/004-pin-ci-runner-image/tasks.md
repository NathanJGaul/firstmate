# Tasks: Pin the CI Runner Image

**Feature**: `004-pin-ci-runner-image` | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md) | **Test list**: [tdd/test-list.md](tdd/test-list.md)

Behavior tasks are mandatory and precede their implementation tasks, per `tdd/test-list.md`.
Each behavior task is one red-green-refactor cycle recorded in `tdd/cycle-log.md`.

## Phase 1: Setup

- [x] T001 Read `firstmate-coding-guidelines` and `spec-kit-workflow`, pull the failing hosted logs for the seven jobs, and reproduce each failing script in an Ubuntu 26.04 container.
- [x] T002 Classify each failure (environment, genuine drift, or unproven flake) and record the classification outside the repository.
- [x] T003 Write `spec.md`, `plan.md`, `tasks.md`, and `tdd/test-list.md`.

## Phase 2: Behavior tasks (test first)

- [x] T004 Behavior: the workflow contract test fails naming each Linux job that uses a floating runner label (US1.2, FR-002).
- [x] T005 Behavior: the Calm Pi queued-operational-rows case reaches its assertions with Pi 1.5.2 (US2.1, FR-005).

## Phase 3: Implementation

- [x] T006 Pin the eight Linux jobs to `ubuntu-24.04` and add the pin comment in `.github/workflows/ci.yml` (covers T004, US1.1, FR-001, FR-003).
- [x] T007 Name `ubuntu-24.04` in `docs/fm-test-portable-shards.md` (US1.4, FR-004).
- [x] T008 Add `pendingBashComponents: []` to the fake Pi host in `tests/fm-calm-pi-extension.test.sh` (covers T005, US2.2, FR-005).

## Phase 4: Verification

- [x] T009 Run `tests/fm-ci-workflow.test.sh`, `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, and the Calm Pi test in 24.04 and 26.04 containers; record results in `tdd/verification.md`.
- [x] T010 Deliberate-mutant evidence: restore one floating label and prove the guard names it; remove the host field and prove the Calm Pi case fails.
- [x] T011 Write `checklist.md`, `analyze.md`, and `converge.md`.

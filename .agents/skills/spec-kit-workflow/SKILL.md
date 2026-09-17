---
name: spec-kit-workflow
description: >-
  Agent-only procedure for integrating Spec-Kit Core and Spec-Kit-TDD into every
  project and enforcing the complete specification, test-driven implementation,
  audit, and convergence lifecycle.
user-invocable: false
metadata:
  internal: true
---

# spec-kit-workflow

Load this skill before initializing a project, dispatching a ship task, or starting implementation in any project.
It owns the integration contract between Firstmate, Spec-Kit Core, and Spec-Kit-TDD.
Firstmate still owns project routing, isolated worktrees, delivery paths, supervision, and merge authority.

## Project setup

Every project must contain a working `.specify/` installation before implementation work starts.
Use the installed `specify` CLI from the project root:

```sh
specify init --here --force --non-interactive --integration claude
printf 'y\n' | specify extension add tdd --from https://github.com/d0whc3r/spec-kit-tdd/releases/download/v1.1.2/tdd-1.1.2.zip --force
specify integration status
specify extension list
```

Run `/speckit.tdd.setup` once per project after the test stack is available.
The setup must execute every command it records and write `.specify/memory/tdd-profile.md`.
A red suite baseline, missing runner, unusable single-test command, or unverified acceptance runner is a blocker for the affected TDD guarantee and must be reported rather than guessed around.
Do not add coverage, mutation, property-testing, or other dependencies as a side effect of setup.

The project constitution must contain the approved TDD principle before feature implementation begins:

- Every behavior change is driven by a test that failed first.
- The failure is recorded in `specs/<feature>/tdd/cycle-log.md`.
- Test tasks precede implementation tasks.
- Tests are never weakened, skipped, deleted, or filtered to reach green.
- Every acceptance criterion has a real-entry-point acceptance test.
- Refactoring happens only on green.
- Test strength is verified with mutation testing or deliberate mutants.

Apply that principle only after the captain approves its exact wording when the project's constitution does not already contain an equivalent rule.

## Per-feature lifecycle

Each ship feature runs this ordered lifecycle in its isolated Firstmate worktree:

1. `/speckit.specify` creates `specs/<feature>/spec.md` with acceptance criteria and scope.
2. `/speckit.clarify` resolves ambiguity when the specification or risk assessment requires it.
3. `/speckit.plan` creates `specs/<feature>/plan.md` after the specification is approved.
4. `/speckit.tasks` creates `specs/<feature>/tasks.md` after the plan is approved.
5. `/speckit.tdd.plan` creates `specs/<feature>/tdd/test-list.md` and `cycle-log.md`, and makes behavior test tasks mandatory and first.
6. `/speckit.tdd.run` performs and records RED-GREEN-REFACTOR cycles, with a real failing test before each behavior implementation and one focused commit per completed cycle.
7. `/speckit.tdd.verify` audits test-first evidence, test strength, mutation or deliberate-mutant evidence, and acceptance-criteria coverage from cold context.
8. `/speckit.implement` completes only the remaining non-behavior tasks and remediation tasks.
9. `/speckit.checklist` records the quality gates for the completed implementation.
10. `/speckit.analyze` checks implementation against the specification, plan, and task list.
11. `/speckit.converge` records merge readiness, risk, evidence, and any remaining work.

Do not skip or reorder a lifecycle step.
A declined clarification is recorded as a decision; an unresolved specification, plan, task list, TDD red, verification finding, or convergence finding remains a blocker.
Captain approval is required for the specification, plan, task list, escalated findings, and merge authority.

## Required artifacts

A feature is not ready for Firstmate delivery until these artifacts exist and are internally consistent:

- `specs/<feature>/spec.md`
- `specs/<feature>/plan.md`
- `specs/<feature>/tasks.md`
- `specs/<feature>/tdd/test-list.md`
- `specs/<feature>/tdd/cycle-log.md`
- `specs/<feature>/tdd/verification.md`
- `specs/<feature>/checklist.md`
- `specs/<feature>/analyze.md`
- `specs/<feature>/converge.md`

A worker reports the feature only after the lifecycle artifacts, implementation, and selected Firstmate delivery checks are complete.
Investigation-only scouts may use the specification and planning artifacts without implementing or claiming a TDD-ready feature.

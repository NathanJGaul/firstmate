# Implementation Checklist: Pin the CI Runner Image

**Feature**: `004-pin-ci-runner-image` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Functional requirements

- [x] FR-001 Every Linux job in `.github/workflows/ci.yml` runs on `ubuntu-24.04`; the macOS job keeps `macos-latest`.
- [x] FR-002 `tests/fm-ci-workflow.test.sh` fails naming each Linux job with a floating label and refuses to pass when no Linux job exists.
- [x] FR-003 One comment above `jobs:` states why the image is pinned and what must land before it moves.
- [x] FR-004 `docs/fm-test-portable-shards.md` names `ubuntu-24.04` as the source of its balance hints.
- [x] FR-005 The Calm Pi test's fake host defines `pendingBashComponents`.
- [x] FR-006 No assertion was weakened, skipped, or deleted; the only test change besides the new guard is one added fixture field.

## Acceptance scenarios

- [x] US1.1 Eight Linux jobs name `ubuntu-24.04`.
- [x] US1.2 The guard named each of eight floating jobs while red, and named `tests-herdr` when one label was restored.
- [x] US1.3 The macOS job is not named by the guard.
- [x] US1.4 The documentation line names `ubuntu-24.04`.
- [x] US2.1 The Calm Pi file passes with Pi 1.5.2.
- [x] US2.2 The Calm Pi file passes with Pi 1.3.0, which never reads the field.

## Quality gates

- [x] `bin/fm-lint.sh` at the pinned ShellCheck 0.11.0 and actionlint 1.7.12 is clean, including full-mode ShellCheck on both changed tests.
- [x] `bin/fm-doc-audience-check.sh` reports `ok`.
- [x] Every sentence of the new Markdown sits on its own line and no em dash was added.
- [x] No agent name appears as a commit co-author.
- [x] `tests/fm-ci-workflow.test.sh` passes in full, and its two mutants (one floating label, no Linux job) are killed.
- [ ] Hosted checks on the delivery PR are green (SC-003): recorded in the final status report, not in this file.

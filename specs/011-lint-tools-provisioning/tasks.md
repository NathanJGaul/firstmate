# Tasks: Pinned Lint Tools Visible to the No-Mistakes Pipeline

**Note**: tests are mandatory and must be observed failing first; every behavior marker `[A#]` and `[U#]` refers to `tdd/test-list.md`.

**Input**: `specs/011-lint-tools-provisioning/` (spec.md, plan.md, research.md, quickstart.md)

## Phase 1: Setup

- [X] T001 Register the new suite `tests/fm-lint-tools.test.sh` in the family and weight tables of `bin/fm-test-run.sh` and the changed-file mapping that already names `bin/fm-lint.sh`

## Phase 2: Foundational

- [X] T002 Create `bin/fm-lint-tools-lib.sh` owning `fm_lint_tools_dir` and `fm_lint_tool_resolve`

## Phase 3: User Story 1 - The pipeline's lint step finds the pinned tools (P1)

**Independent test**: run `bin/fm-lint.sh` under `env -i` with a daemon-like search path after provisioning.

- [X] T003 [US1] [A1] [A2] [A3] [U1] [U2] [U3] [U4] Write tests in `tests/fm-lint-tools.test.sh` for managed-first resolution over an off-pin search-path tool, search-path acceptance of a pinned tool, and off-pin refusal (red first)
- [X] T004 [US1] [A1] [A2] [A3] [U1] [U2] [U3] [U4] Make `bin/fm-lint.sh` resolve ShellCheck through the library
- [X] T005 [US1] [A1] [A3] Make `bin/fm-lint-workflows.sh` resolve actionlint through the library
- [X] T006 [US1] [U10] [U11] Set `FM_LINT_TOOLS_DIR` to an empty directory in the missing-tool tests of `tests/fm-lint.test.sh` and `tests/fm-lint-workflows.test.sh`

## Phase 4: User Story 2 - One command provisions both tools (P1)

**Independent test**: run the provisioning command twice against a temporary directory with stubbed downloads.

- [X] T007 [US2] [A4] [A5] [A6] [A7] [U5] [U6] [U7] [U8] [U9] Write tests in `tests/fm-lint-tools.test.sh` for default-destination installers, provisioning, idempotence, bad checksum, and `--check` (red first)
- [X] T008 [US2] [U5] [U6] Default the destination of `bin/fm-install-shellcheck.sh` and `bin/fm-install-actionlint.sh` to the managed directory
- [X] T009 [US2] [A4] [A5] [A6] [A7] [U7] [U8] [U9] Create `bin/fm-install-lint-tools.sh`

## Phase 5: User Story 3 - A missing tool says how to fix it (P2)

- [X] T010 [US3] [A8] Write the message test in `tests/fm-lint-tools.test.sh` (red first)
- [X] T011 [US3] [A8] Update the missing-tool messages in `bin/fm-lint.sh` and `bin/fm-lint-workflows.sh`

## Phase 6: Polish

- [X] T015 [U12] Guard the per-root RSS assertion in `tests/fm-lint.test.sh` so it applies only where `/usr/bin/time` exists (red first on this host)

- [X] T012 Document the managed directory and provisioning in `CONTRIBUTING.md` and `docs/configuration.md`
- [X] T013 Run `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, and the touched suites
- [X] T014 Prove the real pinned tools resolve from `env -i` using a temporary managed directory and record the evidence outside the worktree

## Dependencies

T002 precedes T003-T011; T001 precedes any run through `bin/fm-test-run.sh`; T012-T014 come last.

## Acceptance gates

- [X] T016 [A1] [A2] [A3] Story US1 is complete only when A1, A2, and A3 are green through the real entry points
- [X] T017 [A4] [A5] [A6] [A7] Story US2 is complete only when A4 through A7 are green
- [X] T018 [A8] Story US3 is complete only when A8 is green

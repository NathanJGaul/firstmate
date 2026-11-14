# Tasks: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md) | **Test list**: [tdd/test-list.md](tdd/test-list.md)

Behavior tasks are mandatory and precede their implementation tasks, per `tdd/test-list.md`.
Each behavior task is one red-green-refactor cycle recorded in `tdd/cycle-log.md`.

## Phase 1: Setup

- [x] T001 Read `firstmate-coding-guidelines`, `spec-kit-workflow`, and the existing merge script header, and record the established suite baseline for `tests/fm-pr-merge.test.sh`.
- [x] T002 Write `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, and `checklists/requirements.md`.

## Phase 2: Behavior tasks (test first)

- [x] T003 Behavior: a matching head with every job passing and a required check that never reported merges once and records the landed merge (US1.1, FR-003, FR-005, FR-008, FR-011).
- [x] T004 Behavior: a red hosted check whose exact name is a passing job is waived and the merge proceeds (US1.2, FR-008).
- [x] T005 Behavior: no forge write other than the merge command happens on the evidence path (US1.3, FR-010).
- [x] T006 Behavior: a head mismatch refuses and names both commits (US2.1, FR-005, FR-006).
- [x] T007 Behavior: a recorded failed job refuses and names the job (US2.2, FR-007).
- [x] T008 Behavior: a check outside the file's coverage refuses and says the file does not cover it (US2.3, FR-008).
- [x] T009 Behavior: an unusable file refuses before metadata is recorded (US2.4, FR-012).
- [x] T010 Behavior: the flag is refused while the away record exists, and restored once it is archived (US3.1, US3.2, FR-009).
- [x] T011 Behavior: the flag is refused for a forge whose merge already requires its head pipeline (US3.3, FR-009).
- [x] T012 Behavior: the flag is accepted once per call and its inline-value spelling is refused (FR-004).
- [x] T013 Behavior: the runner emits a result file naming the run's full head and one entry per printed job and aggregate line (US4.1, US4.2, US4.3, FR-001, FR-002, FR-003).

## Phase 3: Implementation

- [x] T014 Implement `--local-ci-result` parsing, validation, and the failed-job refusal in `bin/fm-pr-merge.sh` (covers T003, T004, T005, T006, T007, T009, T012).
- [x] T015 Implement the coverage-aware waiver inside `github_verify_mergeable`, including the head comparison and the uncovered-check line (covers T003, T004, T006, T008).
- [x] T016 Add the away refusal and the GitLab refusal (covers T010, T011).
- [x] T017 Add the result-file emission to the private runner `data/pricing-sheet-local-ci/local-ci.sh` (covers T013).
- [x] T018 Update the merge tool's header and usage line as the single owner of the flag contract (covers T014, T015, T016, FR-014).

## Phase 4: Documentation and verification

- [x] T019 Update the maintained prose that names the attended merge waivers: `.agents/skills/afk/SKILL.md`, `docs/pi-supervision-branch.md`, and `docs/scripts.md`.
- [x] T020 Run `bin/fm-lint.sh` and the full `tests/fm-pr-merge.test.sh` suite, and record the results in `tdd/verification.md`.
- [x] T021 Deliberate-mutant evidence: break the head comparison, the failed-job refusal, and the name matching one at a time and prove the tests catch each.
- [x] T022 Run `bin/fm-doc-audience-check.sh` and write `checklist.md`, `analyze.md`, and `converge.md`.

## Follow-ups (not built here)

- Recorded in `converge.md`: an optional runner `--parallel` mode, an automatic rerun of a shard that failed only on a test timeout, and the `playwright.config.ts` `webServer.timeout` passthrough.
- Out of scope by the brief and left as they are: merge-authority policy, the auto-mode classifier, hosted-check handling beyond what the flag reads, branch protection.

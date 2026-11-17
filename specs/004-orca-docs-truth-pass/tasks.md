# Tasks: Orca Documentation Truth Pass

**Input**: Design documents from `specs/004-orca-docs-truth-pass/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/claim-audit.md, quickstart.md, tdd/test-list.md

Tests are mandatory.
For this prose-only feature a test is a claim audit: `tdd/claim-audit.sh`, which greps the owning file for a stale statement or a required statement and is committed before the edits so its red run is in git history.
Each test task precedes the edit task for the same claim, and the audit must be observed failing for the right reason before the edit starts.
Bracketed `[A#]` and `[U#]` markers name the behavior on `tdd/test-list.md` that a task covers, and `[L#]` markers name the claim-ledger row in `data-model.md`.
The four stories touch disjoint files, so they can proceed in any order, and `docs/orca-backend.md` is the single owner of the three captain decisions.

## Phase 1: Setup

- [X] T001 Write the claim audit at `specs/004-orca-docs-truth-pass/tdd/claim-audit.sh`: it takes one behavior id (`A1` to `A16`, `U1` to `U32`) or `all`, greps the owning file for the stale or required statement that behavior names (contract C1 to C3 in `contracts/claim-audit.md`), exits nonzero with the failing id, and leaves the worktree untouched.
- [X] T002 Record the baseline in `specs/004-orca-docs-truth-pass/tdd/cycle-log.md`: the audit run on the base commit with the expected reds and the BASELINE greens, and `tests/fm-control.test.sh` green on the base commit (the four other suites are already recorded).

## Phase 2: User Story 1 - Operator learns what Orca supports on Linux (Priority: P1)

**Goal**: `docs/orca-backend.md` is true on Linux and macOS and states the three captain decisions once.

**Independent Test**: the audit's A1 to A7 behaviors, then a cold read answering the seven questions in User Story 1.

- [X] T003 [US1] [A1] [A2] [U1] [U2] [U3] [U4] [U5] [U6] Test: run the audit for platform, setup, `PATH`, app window, and version behaviors against `docs/orca-backend.md`; observe `A1`, `A2`, `U1`, `U2`, `U4`, `U5`, and `U6` fail and `U3` pass.
- [X] T004 [US1] [A1] [A2] [U1] [U2] [U4] [U5] [U6] [L1] [L2] [L7] [L8] Implement: patch the intro, setup, prerequisites, and observation paragraphs of `docs/orca-backend.md` for platforms, the version and capability statement, the `PATH` requirement, and the macOS-only app window, keeping the macOS facts qualified.
- [X] T005 [US1] [A3] [A4] [A5] [A6] [U7] [U8] [U9] [U10] [U11] Test: run the audit for native agent state, delivered keys, linked worktrees, and the startup terminal against `docs/orca-backend.md`; observe all of them fail.
- [X] T006 [US1] [A3] [A4] [A5] [A6] [U7] [U8] [U9] [U10] [U11] [L3] [L4] [L5] [L6] Implement: patch the key sentence, the busy-signal sentence, the verified-terminal-shape sentences, and the trust limit in `docs/orca-backend.md`.
- [X] T007 [US1] [A7] [U12] [U13] [U14] [U15] Test: run the audit for the three captain decisions and the interrupt, exit, and relaunch refusal against `docs/orca-backend.md`; observe all of them fail.
- [X] T008 [US1] [A7] [U12] [U13] [U14] [U15] [L9] [L10] [L11] Implement: add one short operating-posture section to `docs/orca-backend.md` with long or high-value ships on Herdr, folder-registered projects using the per-task backend override, away and quiet modes refused with an Orca-hosted primary, and the control-plane refusal.
- [X] T009 [US1] [U16] [U17] Test and verify: the stale-phrase absence behavior `U16` and the retained-content baseline `U17` pass for `docs/orca-backend.md`, `bin/fm-doc-audience-check.sh` passes, and every link in the file resolves.
- [X] T010 [US1] [A1] [A2] [A3] [A4] [A5] [A6] [A7] Outer-loop gate: A1 to A7 are green before User Story 1 is complete.

## Phase 3: User Story 2 - Recovery agent is told what refuses on Orca (Priority: P1)

**Goal**: The recovery skill and the control document say what refuses on Orca and why, without the false reason.

**Independent Test**: the audit's A8 to A10 behaviors.

- [X] T011 [US2] [A8] [A9] [U18] [U19] [U20] [U21] Test: run the audit against `docs/agent-control.md`; observe `U18` and `U19` fail and `U20` and `U21` pass.
- [X] T012 [US2] [A8] [U18] [U19] [L4] Implement: patch the one sentence in `docs/agent-control.md` that gives the Orca key-delivery reason, adding a pointer to `docs/orca-backend.md`.
- [X] T013 [US2] [A10] [U22] [U23] Test: run the audit against `.agents/skills/stuck-crewmate-recovery/SKILL.md`; observe `U22` fail and `U23` pass.
- [X] T014 [US2] [A10] [U22] [U23] [L12] Implement: add the one line to `.agents/skills/stuck-crewmate-recovery/SKILL.md` immediately after the sentence that points Orca tasks at their recorded identity.
- [X] T015 [US2] [A8] [A9] [A10] Outer-loop gate: A8 to A10 are green, the capability matrix is unchanged, and `bin/fm-doc-audience-check.sh` passes.

## Phase 4: User Story 3 - Maintainer finds Linux evidence beside macOS (Priority: P2)

**Goal**: The verification record holds both platform entries, dated and versioned.

**Independent Test**: the audit's A11 and A12 behaviors.

- [X] T016 [US3] [A11] [A12] [U24] [U25] [U26] [U27] [U28] Test: run the audit against `docs/verification/runtime-backends.md`; observe `U25` to `U28` fail and `U24` pass.
- [X] T017 [US3] [A11] [A12] [U24] [U25] [U26] [U27] [U28] [L13] Implement: label the existing Orca evidence as macOS 1.4.116 and add the Linux headless 1.4.261 subsection to `docs/verification/runtime-backends.md`, naming the fake-Orca regression suites and the absence of a live Orca lane.
- [X] T018 [US3] [A11] [A12] Outer-loop gate: A11 and A12 are green and every line of the new entry is traced to `data-model.md` evidence.

## Phase 5: User Story 4 - Trust-check comment matches reality (Priority: P2)

**Goal**: The comment in `bin/fm-claude-trust.sh` states the verified Orca worktree shape, and behavior is untouched.

**Independent Test**: the audit's A13 and A14 behaviors and `tests/fm-claude-trust.test.sh`.

- [X] T019 [US4] [A13] [A14] [U29] [U30] [U31] [U32] Test: run the audit against `bin/fm-claude-trust.sh`; observe `U29` and `U30` fail and `U31` and `U32` pass.
- [X] T020 [US4] [A13] [U29] [U30] [U31] [L5] Implement: replace the Orca sentences of the structural-test comment in `bin/fm-claude-trust.sh` with the verified linked-worktree finding, the folder-registered residual, and a pointer to `docs/verification/runtime-backends.md`, keeping the structural-test rationale, and editing comment lines only.
- [X] T021 [US4] [A13] [A14] [U32] Outer-loop gate: `A13` and `A14` are green, `bash -n bin/fm-claude-trust.sh` passes, `bin/fm-lint.sh` is clean, and `tests/fm-claude-trust.test.sh` passes.

## Phase 6: Polish and cross-cutting

- [ ] T022 [A15] [A16] Test and verify: the audit's file-set behavior `A15` and style behavior `A16` pass over the complete branch diff.
- [ ] T023 Mutation check: reinstate one stale sentence in a scratch copy of `docs/orca-backend.md` and one in a scratch copy of `docs/agent-control.md`, confirm the audit goes red for each, and record both in `tdd/cycle-log.md` and `tdd/verification.md`.
- [ ] T024 Re-read every changed claim against the evaluation report's appendix and the code it describes, walking each row of `data-model.md`, and soften or drop any claim the evidence does not support.
- [ ] T025 Run `bin/fm-doc-audience-check.sh`, `tests/fm-documentation-audiences.test.sh`, `tests/fm-claude-trust.test.sh`, `tests/fm-backend-orca.test.sh`, `tests/fm-control.test.sh`, `tests/fm-backend.test.sh`, and `bin/fm-lint.sh`, and confirm no test file changed.
- [ ] T026 Review the complete branch diff again against the documentation change review criteria in `firstmate-coding-guidelines`, then write `checklist.md`, `analyze.md`, and `converge.md` in `specs/004-orca-docs-truth-pass/`.

## Dependencies

- T001 and T002 precede everything.
- Within each story a test task precedes its edit task, and the outer-loop gate closes the story.
- Stories 1 to 4 are independent of each other and touch disjoint files; T022 to T026 follow all of them.

## Implementation Strategy

Deliver User Story 1 first because it is the page that decides backend choice, then User Story 2 because the recovery playbook cannot be followed on Orca, then the two P2 stories.
Commit one focused cycle at a time and keep each file's edit confined to the claims in its ledger rows.

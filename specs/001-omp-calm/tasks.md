# Tasks: OMP Calm presentation

**Input**: Design documents from `/specs/001-omp-calm/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/omp-extension.md

**Tests**: Required. Every behavior task starts with an executable test that fails for the missing behavior.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the OMP extension and test surfaces without changing existing harness behavior.

- [X] T001 [P] Add the OMP Calm extension test entry point in `tests/fm-calm-omp-extension.test.sh` using the existing `tests/lib.sh` helpers and `bin/fm-test-run.sh` conventions.
- [X] T002 [P] Add the harness-neutral Calm policy export needed by OMP under `.claude/mods/firstmate-calm/lib/` while preserving the existing Pi import paths.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Make shared preference, sprite, and adapter diagnostics executable before story-specific implementation.

- [X] T003 [P] [U1] Add failing preference and policy contract cases to `tests/fm-calm-omp-extension.test.sh` for the shared `config/calm` path, `on`/`max` parsing, `on`/`off` serialization, and operational-input classification.
- [X] T004 [P] [U2] Add failing shared sprite projection and managed-timer lifecycle cases to `tests/fm-calm-omp-extension.test.sh` for deterministic frames, resize bounds, and cleanup on every terminal lifecycle.
- [X] T005 [P] [U3] Add failing adapter-diagnostic cases to `tests/fm-calm-omp-extension.test.sh` for missing or throwing OMP seams that must not disable unrelated adapters.
- [X] T006 [U1] Implement the harness-neutral Calm policy exports in `.claude/mods/firstmate-calm/lib/fm-calm-presentation.ts` and update Pi's visibility adapter to consume them without changing its behavior.
- [X] T007 [U2] Implement OMP working-row projection helpers in `.omp/extensions/lib/fm-calm-omp-presentation.ts` using the shared sprite core and one managed timer lifecycle.
- [X] T008 [U3] Implement per-adapter diagnostic helpers in `.omp/extensions/lib/fm-calm-omp-presentation.ts` with stable names and independent failure handling.


**Checkpoint**: Shared policy, deterministic OMP presentation helpers, and diagnostics are testable before wiring the extension factory.

---

## Phase 3: User Story 1 - Toggle shared Calm preference in OMP (Priority: P1) 🎯 MVP

**Goal**: OMP exposes `/calm`, persists the existing shared choice, restores it at session start, and reports write failures without changing execution.

**Independent Test**: Exercise the extension factory with a fake OMP API and isolated `FM_HOME`, invoke the registered command, and inspect the preference, notification, and active state across reloads and write failures.

### Tests for User Story 1

- [X] T009 [P] [A1][A2][A3][A4] Add failing OMP `/calm` command tests in `tests/fm-calm-omp-extension.test.sh` for off-by-default, on/off persistence, session restoration, no transcript-row response, and failed writes.

### Implementation for User Story 1

- [X] T010 [A1][A2][A3][A4] Implement shared preference loading and atomic persistence in `.omp/extensions/fm-calm.ts` through the existing `calmPreferencePath`, `parseCalmPreference`, and `serializeCalmPreference` policy.
- [X] T011 [A1][A2][A3][A4] Register `/calm` and OMP session lifecycle handlers in `.omp/extensions/fm-calm.ts`, including redraw of supported surfaces without sending a model message.

**Checkpoint**: OMP can toggle and restore the shared preference independently of the working and transcript adapters.

---

## Phase 4: User Story 2 - Keep OMP work and conversation readable (Priority: P1)

**Goal**: Calm-on OMP shows the animated shared working presentation and hides only supported rows while preserving genuine conversation and execution data.

**Independent Test**: Drive fake `session_start`, `agent_start`, `agent_end`, and `/calm` events through the extension API and verify working messages, timers, supported legacy-row suppression, and ordinary unsupported and Calm-off behavior.

### Tests for User Story 2

- [X] T012 [P] [A5][A6][A7][A8] Add failing working-presentation tests in `tests/fm-calm-omp-extension.test.sh` for agent-start animation, frame updates, resize projection, Calm-off stock restoration, and cleanup on settle/abort/shutdown.
- [X] T013 [P] [A6][A7][A8] Add failing preservation and supported-row tests in `tests/fm-calm-omp-extension.test.sh` for legacy custom-message hiding, untouched native tools, and visible unsupported operational/assistant rows.
- [X] T014 [A5][A6][A7][A8] Wire `.omp/extensions/fm-calm.ts` to the managed OMP working-message timer and shared sprite projection, with one timer per logical run and default-message restoration.
- [X] T015 [A6][A7][A8] Implement `.omp/extensions/fm-calm.ts` legacy message renderer and leave unsupported native tool rows ordinary, preserving execution, arguments, results, and exports.
- [X] T016 [A6][A7][A8] Add supported-surface redraw on toggle in `.omp/extensions/fm-calm.ts` without changing session messages or model context.

**Checkpoint**: OMP Calm presentation is a drawing-only enhancement with explicit supported and unsupported row boundaries.

---

## Phase 5: User Story 3 - Continue safely across OMP API variation (Priority: P2)

**Goal**: Missing OMP presentation seams produce targeted diagnostics while preference handling, working presentation, remaining adapters, and Pi/Claude behavior continue.

**Independent Test**: Remove or throw from each fake OMP seam independently and verify one diagnostic per seam with no loss of unrelated registration or execution.

### Tests for User Story 3

- [X] T017 [P] [A9][A10][A11] Add failing compatibility tests in `tests/fm-calm-omp-extension.test.sh` for unavailable working-message, legacy-renderer, and unsupported generic-row seams.
- [X] T018 [P] [A11] Add failing regression checks in `tests/fm-calm-claude-mod.test.sh` and `tests/fm-calm-pi-extension.test.sh` for unchanged shared preference, sprite, visibility, and operational-input behavior.
- [X] T019 [A9][A10][A11] Install each OMP adapter independently in `.omp/extensions/fm-calm.ts` and report method/registration failures with adapter names while retaining unrelated adapters.
- [X] T020 [A11] Update `.claude/mods/firstmate-calm` shared imports and `.pi/extensions/lib` links only as needed to preserve Pi and Claude Code behavior, with no harness-specific preference fork.

**Checkpoint**: OMP compatibility degradation is targeted and existing Calm ports remain green.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Document the current OMP contract and record repeatable maintainer evidence.

- [X] T021 [P] Update `docs/calm.md` with the OMP section, supported adapters, preservation guarantee, and explicit unsupported boundaries.
- [X] T022 [P] Update `docs/calm-mode-feasibility.md` with OMP 18.6.1 API evidence, diagnostics behavior, and focused regression commands.
- [X] T023 [P] Update `docs/verification/runtime-backends.md` with the dated exact OMP version and smoke/behavior commands and observed output.
- [X] T024 Run `bin/fm-doc-audience-check.sh` and the focused Calm test scripts from `specs/001-omp-calm/quickstart.md`.
- [X] T025 Run the complete relevant behavior suite and review the complete branch diff for preservation and documentation-owner compliance.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; establishes the test and shared-policy surfaces.
- **Foundational (Phase 2)**: Depends on Setup; test tasks T003-T005 precede implementation T006-T008.
- **User Story 1 (Phase 3)**: Depends on Foundational; T009 precedes T010-T011.
- **User Story 2 (Phase 4)**: Depends on Foundational and the `/calm` state contract from User Story 1; T012-T013 precede T014-T016.
- **User Story 3 (Phase 5)**: Depends on adapter implementations from User Story 2; T017-T018 precede T019-T020.
- **Polish (Phase 6)**: Depends on all user stories and TDD verification.

### Parallel Opportunities

- T001 and T002 can run in parallel.
- T003, T004, and T005 can run in parallel because they cover independent pure seams.
- T009 can run independently after the foundational policy is defined.
- T012 and T013 can run in parallel after the `/calm` state contract is fixed.
- T017 and T018 can run in parallel after the adapter contract is fixed.
- T021, T022, and T023 can run in parallel after behavior is complete.

## Implementation Strategy

1. Establish the spec, plan, test list, and red baseline.
2. Drive foundational pure behaviors through red-green-refactor cycles.
3. Ship User Story 1 as the minimum viable OMP toggle and persistence slice.
4. Add the working row and supported row adapters, then prove preservation.
5. Add independent diagnostics and existing-harness regression checks.
6. Update current docs and maintainer evidence, then run focused and complete validation.

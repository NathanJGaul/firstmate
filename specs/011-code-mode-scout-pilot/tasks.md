# Tasks: Code Mode Scout Pilot

**Tests**: Required first. Each behavior test is seen failing for the right reason before its implementation, recorded in `tdd/cycle-log.md`.
New portable tests live in `tests/fm-spawn-claude-code-mode.test.sh`; run with `bin/fm-test-run.sh tests/fm-spawn-claude-code-mode.test.sh`.

- [X] T001 Baseline: run the existing spawn launch-line suites that pin the `env -u` prefix and record in `tdd/cycle-log.md`.
- [X] T002 [US1] Tests: knob parsing and refusals (FR-001), scout on, ship off, secondmate off, relaunch (FR-002, FR-003).
- [X] T003 [US1] Tests: allowlist and stray-environment behavior through a real `env -i` execution (FR-004).
- [X] T004 [US2] Tests: acceptance check absent, false, present, unreadable, pinned root; one skip line; read-only (FR-005, FR-006).
- [X] T005 [US1] Tests: auto permission mode forces off with a reason (FR-007).
- [X] T006 [US3] Test: the supervision engine does not inherit the variable (FR-008); the knob is not inherited into secondmate homes (FR-009).
- [X] T007 Implement `bin/fm-claude-code-mode-lib.sh` and the `bin/fm-spawn.sh` wiring and header.
- [X] T008 Implement the engine unset.
- [X] T009 Update the existing golden launch assertions for the new `-u` token.
- [X] T010 [US4] Write `tests/fm-claude-codemode-live-e2e.test.sh` and its login helper, register in `bin/fm-test-run.sh`; run the offline parts (gate, refusals) now.
- [X] T011 [US5] Docs: `docs/configuration.md`, the Claude adapter reference, `docs/documentation-audiences.json` entries if required.
- [ ] T012 Append `needs-decision [key=code-mode-pilot-login]` with the exact sign-in command and stop until answered; then run the live E2E and record the dated result in `docs/verification/supervision.md`.
- [X] T013 `/speckit.tdd.verify` with mutants; `/speckit.implement`, `/speckit.checklist`, `/speckit.analyze`, `/speckit.converge`.
- [X] T014 `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, `bin/fm-test-run.sh --check-coverage`, the changed suites.

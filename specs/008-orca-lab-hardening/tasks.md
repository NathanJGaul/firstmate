# Tasks: Orca Live Lab Hardening

Tests precede implementation.

- [x] T001 [US1] Guard test: launcher write refuses a missing, empty, operator-HOME, HOME-containing, Orca-directory, agent-config-directory, and non-fresh home and writes nothing (tests/fm-backend-orca-lab-guard.test.sh)
- [x] T002 [US1] Guard test: the launcher exports the lab HOME over the caller's real HOME and drops agent-config pointers (tests/fm-backend-orca-lab-guard.test.sh)
- [x] T003 [US2] Guard test: the runtime PATH is exactly fake-bin plus /usr/bin:/bin, and the checker refuses agent binaries and empty or relative entries (tests/fm-backend-orca-lab-guard.test.sh)
- [x] T004 [US3] Guard test: config paths outside the lab home fail the paths check (tests/fm-backend-orca-lab-guard.test.sh)
- [x] T005 [US1] Implement home validation and the pinned launcher (tests/orca-lab-safety.sh)
- [x] T006 [US2] Implement the runtime PATH builder and checker (tests/orca-lab-safety.sh)
- [x] T007 [US3] Implement the config-path check (tests/orca-lab-safety.sh)
- [x] T008 [US1-3] Wire the live lane: launcher home argument, runtime PATH, hooks status assertion (tests/fm-backend-orca-smoke.test.sh)
- [x] T009 [US4] Record the boot probe, rules, and inherited-handle trace (docs/verification/runtime-backends.md)
- [x] T010 Run the live lane inside its isolated lab with a pinned HOME and record the result

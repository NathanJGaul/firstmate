# Analysis: Orca Live Lab Hardening

| Requirement | Task | Implementation | Test |
| --- | --- | --- | --- |
| FR-001 | T001, T002, T005 | `orca_lab_validate_home`, `orca_lab_write_launcher` | guard `L1` launcher and refused-home cases |
| FR-002 | T002, T005 | launcher `unset` line | guard `L1` pointer cases |
| FR-003 | T003, T006 | `orca_lab_runtime_path`, `orca_lab_assert_path_agent_free` | guard `L1` PATH cases |
| FR-004 | T008 | `start_runtime` in the smoke lane | live run (no portable test starts a runtime) |
| FR-005 | T004, T007, T008 | `orca_lab_paths_under_home`, lane assertion H1 | guard `L1` config-path cases, live H1 |
| FR-006 | T001-T004 | guard test | self |
| FR-007 | T009 | verification record | `bin/fm-doc-audience-check.sh` |

Findings: none blocking.
FR-004 has no portable test because starting the runtime needs Orca; it is covered by the live run and by the PATH checker's own cases.
The inherited-handle launch path was traced only for the Herdr-backed worker, and the Orca-backed path is recorded as unknown.

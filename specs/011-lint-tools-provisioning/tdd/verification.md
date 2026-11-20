# TDD Verification: Pinned Lint Tools Visible to the No-Mistakes Pipeline

Verdict: PASS.

## Test-first evidence

Every behavior in `test-list.md` has a cycle in `cycle-log.md` recorded against code that lacked the behavior, with two stated exceptions: A2 and A3 were not individually observed red because the suite stops at its first failure, and U6 characterizes behavior that already existed.
All three are pinned by deliberate mutants below.
Cycles were batched by user story, not committed one per behavior, and the log says so.

## Test strength

No mutation tool is installed, so deliberate mutants were applied one at a time to the production file, the named test re-run, and the file restored.
All 9 were killed:

| mutant | killed by |
| --- | --- |
| the managed directory wins over the search path (M1) | `test_search_path_wins_over_the_managed_directory` |
| a non-executable managed file is accepted (M2) | `test_resolve_ignores_a_non_executable_managed_file` |
| `XDG_CACHE_HOME` is ignored (M3) | `test_dir_default_follows_xdg_then_home` |
| a pinned tool is reinstalled every run (M4) | `test_second_provisioning_downloads_nothing` |
| `--check` installs (M5) | `test_check_reports_without_changing_anything` |
| provisioning calls the daemon (M6) | `test_provisioning_never_touches_the_daemon` |
| an installer ignores the managed default (M7) | `test_installers_default_to_the_managed_directory` |
| the message drops the provisioning command (M8) | `test_missing_tools_name_the_provisioning_command` |
| an off-pin ShellCheck is accepted (M9) | `test_off_pin_managed_tools_are_refused` |

## Acceptance coverage

US1 by A1, A2, A3; US2 by A4, A5, A6, A7; US3 by A8.
FR-001 by A1, A2, U4; FR-002 by U1, U2, U3; FR-003 by A3; FR-004 by the shared library used in every case; FR-005 by U5, U6; FR-006 by A4-A7, U7, U8; FR-007 by A8; FR-008 by U9 and the absence of any daemon call in the proof; FR-009 by the `CONTRIBUTING.md` and `docs/configuration.md` text checked with `bin/fm-doc-audience-check.sh`.
SC-001 by A1 and the real-tool proof; SC-002 by A5 and the proof's second run; SC-003 by the unchanged existing suites; SC-004 by the quickstart.

## Smells

None found.
The fake tools are state-based stand-ins for downloads and archives only, the lint entry points and the provisioning command run for real, and no test asserts source bytes.

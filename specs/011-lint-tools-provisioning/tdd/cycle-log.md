# Cycle Log: Pinned Lint Tools Visible to the No-Mistakes Pipeline

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

Run from the starting commit `55bf3486` before any edit with `bin/fm-test-run.sh tests/fm-lint.test.sh tests/fm-lint-workflows.test.sh`.

- No pinned tools on the search path: both suites exit 1 with the ShellCheck and actionlint "not found" messages, which is the reported defect reproduced on this host.
- Pinned tools staged on the search path from a scratch directory: `tests/fm-lint-workflows.test.sh` exit 0; `tests/fm-lint.test.sh` exit 1 with a single failure, `the fallback attempts lost per-root RSS reporting: unavailable`, because this host has no `/usr/bin/time`.
- full profile suite: not run here, left to CI
- commit: `55bf3486`

Method notes:

- `tests/fm-lint-tools.test.sh` and the two edited suites have no per-test selector, so a single red was observed by running one function through a scratch copy that sources the same file with its bare call lines removed, against the unchanged `bin/`; the wrapper (`run-one.sh`) lives outside the worktree and is not committed.
- Real ShellCheck 0.11.0 and actionlint 1.7.12 were installed into a scratch directory outside the worktree with the existing installers so `bin/fm-lint.sh` and the suites could run on this host.
- Cycles were batched by user story rather than one commit per behavior, which is a deviation from the one-commit-per-cycle cadence; all behaviors of a story share one test file and one pair of entry points.
- The load average on this host stayed above 13, so `tests/fm-lint.test.sh` took about 25 minutes per full run.

## Cycle 1: the managed directory and the lookup (U1-U4, A1-A3)

- tests (new) in `tests/fm-lint-tools.test.sh`: `test_dir_honors_the_override` (U1), `test_dir_default_follows_xdg_then_home` (U2), `test_dir_without_a_home_is_absent_not_an_error` (U3), `test_resolve_ignores_a_non_executable_managed_file` (U4), `test_clean_env_resolves_the_default_managed_directory` (A1), `test_search_path_wins_over_the_managed_directory` (A2), `test_off_pin_managed_tools_are_refused` (A3)
- red against the unchanged code:
  - U1 `_: line 1: .../bin/fm-lint-tools-lib.sh: No such file or directory ... not ok - override lookup failed`
  - U2-U4 passed only once the library existed; they were never run against a missing library individually
  - A1, with the library present but the entry point unchanged: `not ok - lint from a clean environment failed (rc=1)` with `fm-lint.sh: ShellCheck not found; install ShellCheck 0.11.0 ...`
  - A2 and A3 were not individually observed red: the suite stops at its first failure, and A2 holds on the search-path-only behavior as well; both are pinned by deliberate mutants M1 and M9 instead
- green after: `bin/fm-lint-tools-lib.sh` (`fm_lint_tools_dir`, `fm_lint_tool_resolve`), `bin/fm-lint.sh` and `bin/fm-lint-workflows.sh` resolving through it
- regressions found going green and fixed: the existing suites copy `bin/fm-lint.sh` and `bin/fm-lint-workflows.sh` into temporary trees, so each copy now also copies `bin/fm-lint-tools-lib.sh`
- a defect in the new tests found by the repository's own lint: SC2016 on `bash -c '... $1 ...'` was fixed with one driver variable, and `tests/fm-lint.test.sh` caught it through `test_local_exclusion_list_covers_every_no_external_sources_code`
- refactor: the symlinked daemon-like search path is built once per run instead of once per case (the first form took about 6 minutes under load, the second about 46 seconds)

## Cycle 2: existing missing-tool tests on a provisioned machine (U10, U11)

- tests (changed): `test_missing_shellcheck_fails_closed` in `tests/fm-lint.test.sh` and `test_missing_actionlint_fails_closed` in `tests/fm-lint-workflows.test.sh` now set `FM_LINT_TOOLS_DIR` to a nonexistent directory
- red, with a provisioned directory exported by the caller (the state of a provisioned developer machine):
  - U10 `not ok - missing ShellCheck expected exit 1, got 127` (perl absent from the stub path, because ShellCheck was found)
  - U11 `not ok - missing actionlint expected exit 1, got 0` with `fm-lint-workflows.sh: 1 workflow files valid`
- green after: the override added to both tests; both pass with the same provisioned directory exported
- refactor: none

## Cycle 3: the pre-existing RSS assertion (U12)

- test (changed): the per-root RSS assertion in the memory-fallback test of `tests/fm-lint.test.sh` applies only where `/usr/bin/time` exists
- red: the baseline failure itself, `not ok - the fallback attempts lost per-root RSS reporting: unavailable`, observed before any edit and again after the lookup change
- green after: the guard, because `bin/fm-lint.sh` documents that the reading comes from `/usr/bin/time` only where the host ships it and reports `unavailable` otherwise
- refactor: none

## Cycle 4: provisioning, installer defaults, and messages (A4-A8, U5-U9)

- tests (new) in `tests/fm-lint-tools.test.sh`: `test_provisioning_installs_both_pinned_tools` (A4), `test_second_provisioning_downloads_nothing` (A5), `test_a_checksum_mismatch_installs_nothing` (A6), `test_check_reports_without_changing_anything` (A7), `test_missing_tools_name_the_provisioning_command` (A8), `test_installers_default_to_the_managed_directory` (U5), `test_installers_honor_an_explicit_destination` (U6), `test_an_already_pinned_tool_is_skipped` (U7), `test_an_unknown_argument_exits_2_with_usage` (U8), `test_provisioning_never_touches_the_daemon` (U9)
- red against the code after cycle 1:
  - A4 `not ok - provisioning failed (rc=127)` with `env: '.../bin/fm-install-lint-tools.sh': No such file or directory`
  - U5 `not ok - ShellCheck installer with no destination failed`
  - A8 `not ok - the ShellCheck message did not name the provisioning command (missing: 'fm-install-lint-tools.sh')`
  - U6 passed immediately: it characterizes the existing explicit-destination behavior and guards the new default against replacing it
  - A5-A7, U7-U9 need the missing command and could not run before it existed
- green after: `bin/fm-install-lint-tools.sh`, the optional destination in both installers, and the missing-tool messages
- refactor: none

## Evidence outside the suites

`proof-real-tools.txt` (outside the worktree) runs the real installers and entry points from `env -i` with the daemon's own search path and a temporary home: lint fails with the new message before provisioning, `--check` exits 1, provisioning installs both pinned builds, a second run reports both `ok`, `--check` exits 0, and `bin/fm-lint.sh` then resolves ShellCheck 0.11.0 and actionlint 1.7.12 from the managed directory and exits 0.

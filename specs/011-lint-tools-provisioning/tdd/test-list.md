---
feature: 011-lint-tools-provisioning
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 8
planned_at: 55bf3486
updated_at: 55bf3486
suite_baseline: red
---

# Test List: Pinned Lint Tools Visible to the No-Mistakes Pipeline

Baseline note: `tests/fm-lint.test.sh` is red on a host with no GNU time (`/usr/bin/time`) before any edit, because one assertion requires a per-root peak-RSS reading that the production code correctly reports as unavailable there; behavior U12 repairs the test.
The full profile suite is left to CI.
`traces` values name spec acceptance scenarios (`USn.m`) and functional requirements (`FR-nnn`).
The real entry points run under `env -i`; downloads, `uname`, and archive extraction are stubbed with the existing helpers in `tests/fm-lint.test.sh`, and the tools themselves are tiny fakes reporting a version.

## Outer loop: acceptance behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | `fm-lint.sh` run from `env -i` with a daemon-like search path and a provisioned managed directory resolves the pinned ShellCheck, reports the pinned version, runs, and the workflow lint resolves the pinned actionlint | US1.1, FR-001, FR-002 | example | DONE | `tests/fm-lint-tools.test.sh::test_clean_env_resolves_the_default_managed_directory` |
| A2  | A pinned managed tool wins over an off-pin search-path tool; an off-pin search-path tool alone is refused; a pinned search-path tool is accepted with no managed copy | US1.2, FR-001 | example | DONE | `tests/fm-lint-tools.test.sh::test_pinned_managed_wins_over_an_off_pin_search_path_tool`, `test_off_pin_search_path_tools_alone_are_refused`, `test_pinned_search_path_tool_is_accepted_without_a_managed_copy` |
| A3  | A managed ShellCheck or actionlint that is not the pinned version is refused naming the pin | US1.3, FR-003 | example | DONE | `tests/fm-lint-tools.test.sh::test_off_pin_managed_tools_are_refused` |
| A4  | `fm-install-lint-tools.sh` against an empty managed directory installs both tools through the installers and each reports its pin | US2.1, FR-006 | example | DONE | `tests/fm-lint-tools.test.sh::test_provisioning_installs_both_pinned_tools` |
| A5  | A second `fm-install-lint-tools.sh` run performs no download | US2.2, FR-006 | example | DONE | `tests/fm-lint-tools.test.sh::test_second_provisioning_downloads_nothing` |
| A6  | A checksum mismatch makes `fm-install-lint-tools.sh` exit non-zero and install nothing | US2.3, FR-006 | example | DONE | `tests/fm-lint-tools.test.sh::test_a_checksum_mismatch_installs_nothing` |
| A7  | `fm-install-lint-tools.sh --check` reports each tool and exits non-zero when one is missing or off-pin, changing nothing, and zero when both are pinned | US2.4, FR-006 | example | DONE | `tests/fm-lint-tools.test.sh::test_check_reports_without_changing_anything` |
| A8  | With neither location holding the tool, both lint entry points exit 1 naming `fm-install-lint-tools.sh` and the managed directory | US3.1, FR-007 | example | DONE | `tests/fm-lint-tools.test.sh::test_missing_tools_name_the_provisioning_command` |

## Inner loop: unit behaviors

### `bin/fm-lint-tools-lib.sh`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | The directory is `FM_LINT_TOOLS_DIR` when set | FR-002 | example | DONE | `tests/fm-lint-tools.test.sh::test_dir_honors_the_override` |
| U2  | Without the override the directory is under `XDG_CACHE_HOME`, else under `HOME/.cache`, in `firstmate/lint-tools` | FR-002 | example | DONE | `tests/fm-lint-tools.test.sh::test_dir_default_follows_xdg_then_home` |
| U3  | With no override and no home the directory lookup fails and resolution treats it as absent | FR-002, edge cases | example | DONE | `tests/fm-lint-tools.test.sh::test_dir_without_a_home_is_absent_not_an_error` |
| U4  | A non-executable managed file is ignored | edge cases | example | DONE | `tests/fm-lint-tools.test.sh::test_resolve_ignores_a_non_executable_managed_file` |

### `bin/fm-install-shellcheck.sh` and `bin/fm-install-actionlint.sh`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U5  | With no destination argument each installer installs into the managed directory | FR-005 | example | DONE | `tests/fm-lint-tools.test.sh::test_installers_default_to_the_managed_directory` |
| U6  | With an explicit destination each installer installs there and leaves the managed directory untouched | FR-005 | example | DONE | `tests/fm-lint-tools.test.sh::test_installers_honor_an_explicit_destination` |

### `bin/fm-install-lint-tools.sh`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U7  | A tool already at its pin is skipped while the other is installed | FR-006 | example | DONE | `tests/fm-lint-tools.test.sh::test_an_already_pinned_tool_is_skipped` |
| U8  | An unknown argument exits 2 with usage | FR-006 | example | DONE | `tests/fm-lint-tools.test.sh::test_an_unknown_argument_exits_2_with_usage` |
| U9  | The command never invokes a no-mistakes executable | FR-008 | example | DONE | `tests/fm-lint-tools.test.sh::test_provisioning_never_touches_the_daemon` |

### Missing-tool tests in existing suites

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U10 | The existing missing-ShellCheck test passes on a machine with a provisioned managed directory | SC-003 | characterization | BASELINE | `tests/fm-lint.test.sh::test_missing_shellcheck_fails_closed` |
| U11 | The existing missing-actionlint test passes on a machine with a provisioned managed directory | SC-003 | characterization | BASELINE | `tests/fm-lint-workflows.test.sh::test_missing_actionlint_fails_closed` |
| U12 | The fallback RSS assertion in `tests/fm-lint.test.sh` applies only where `/usr/bin/time` exists | SC-003 | example | DONE | `tests/fm-lint.test.sh::the RSS assertion in the memory-fallback test` |

## Invariants and edge cases still to place

None.

## Out of scope

- Documentation text: verified by `bin/fm-doc-audience-check.sh`, not by behavior tests.
- Running the provisioning on the operator machine: an operator step.

## Verification commands

- single: `bin/fm-test-run.sh tests/fm-lint-tools.test.sh`
- suite: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`
- coverage: `bin/fm-test-run.sh --check-coverage`

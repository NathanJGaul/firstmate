---
feature: 005-orca-adapter-hygiene
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 11
planned_at: 018cde5d
suite_baseline: green
---

# Test List: Orca Adapter Hygiene

Adapter tests use the fake `orca` CLI in `tests/fm-backend-orca.test.sh`; bootstrap tests use the fake toolchain in `tests/fm-bootstrap.test.sh`.
`traces` values name spec acceptance scenarios (`US1.n`), functional requirements (`FR-nnn`), and edge cases (`EC`).
No test touches a live Orca; `HOME` and `ORCA_CLI_BIN_DIR` are pinned in every case that depends on CLI discovery.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | A spawn on Orca for a folder-registered project fails before any worktree is created, names the `--backend` escape hatch, and logs no registration, worktree, or terminal call | US1.1, US1.2, FR-001..003 | example | DONE | `tests/fm-backend-orca.test.sh::test_spawn_refuses_a_folder_kind_repo_before_any_mutation` |
| A2 | A spawn on Orca completes when the CLI is only under `ORCA_CLI_BIN_DIR` | US2.2, FR-005, FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_spawn_finds_the_orca_cli_under_orca_cli_bin_dir` |
| A3 | Bootstrap with `backend=orca` and the CLI only under `ORCA_CLI_BIN_DIR` does not report `orca` missing | US2.6, FR-008 | example | DONE | `tests/fm-bootstrap.test.sh::test_orca_backend_resolves_the_cli_from_orca_cli_bin_dir` |
| A4 | Bootstrap on a non-macOS host with no `orca` prints a hint that is not `brew install orca` and names `~/.orca/cli/bin` and `ORCA_CLI_BIN_DIR` | US3.1, FR-009 | example | DONE | `tests/fm-bootstrap.test.sh::test_orca_install_hint_is_platform_aware` |
| A5 | Bootstrap on macOS keeps the Homebrew hint | US3.2, FR-009 | example | DONE | `tests/fm-bootstrap.test.sh::test_orca_install_hint_is_platform_aware` |

## Inner loop: unit behaviors

### `fm_backend_orca_json_get` and `fm_backend_orca_repo_ensure`

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | `repo-kind` returns `result.repo.kind` | FR-001 | example | DONE | `tests/fm-backend-orca.test.sh::test_json_get_reads_repo_kind` |
| U2 | `repo-kind` falls back to `result.kind` and is empty when no kind is present | FR-001, EC | boundary | DONE | `tests/fm-backend-orca.test.sh::test_json_get_reads_repo_kind` |
| U3 | `repo_ensure` for a `folder` repo fails, names the project and `--backend`, prints no id, and issues only `repo show` | FR-001..003 | example | DONE | `tests/fm-backend-orca.test.sh::test_repo_ensure_refuses_a_folder_repo` |
| U4 | `repo_ensure` returns the id for `git` and for a result with no kind | FR-004, EC | example | DONE | `tests/fm-backend-orca.test.sh::test_repo_ensure_accepts_git_and_kindless_repos` |

### `fm_backend_orca_tool_check`

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U5 | `PATH` wins when the CLI is also under `ORCA_CLI_BIN_DIR` and `~/.orca/cli/bin` | US2.1, FR-005 | example | DONE | `tests/fm-backend-orca.test.sh::test_tool_check_resolution_order` |
| U6 | CLI only under `ORCA_CLI_BIN_DIR`: check passes and the next Orca call runs that CLI | US2.2, FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_tool_check_resolution_order` |
| U7 | CLI only under `~/.orca/cli/bin` is found | US2.3 | example | DONE | `tests/fm-backend-orca.test.sh::test_tool_check_resolution_order` |
| U8 | `ORCA_CLI_BIN_DIR` beats `~/.orca/cli/bin` | US2.4 | example | DONE | `tests/fm-backend-orca.test.sh::test_tool_check_resolution_order` |
| U9 | An unset, empty, missing, non-executable, or directory candidate is skipped | EC, FR-005 | boundary | DONE | `tests/fm-backend-orca.test.sh::test_tool_check_skips_unusable_candidates` |
| U10 | Nothing found refuses, names all three locations and the fix, keeps the "not installed" wording, and calls nothing | US2.5, FR-007 | example | DONE | `tests/fm-backend-orca.test.sh::test_tool_check_refusal_is_actionable` |
| U11 | A whole `worktree_create` completes with the CLI only off `PATH` | FR-006 | example | DONE | `tests/fm-backend-orca.test.sh::test_worktree_create_uses_a_cli_found_off_path` |

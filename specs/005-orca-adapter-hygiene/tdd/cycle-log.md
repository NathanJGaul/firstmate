# Cycle Log: Orca Adapter Hygiene

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- `tests/fm-backend-orca.test.sh` at the planning commit: `FM_TEST_SUMMARY total=1 failed=0` (49 s), run from an exported copy of the commit.
- `tests/fm-bootstrap.test.sh` at the planning commit: red on this host before any change.
  `test_session_provider_backends_gate_own_cli_not_tmux` simulates the herdr CLI as missing by leaving it out of the fake toolchain, but the host has a real `herdr` in `/usr/bin`, which the base path still reaches, so the case saw it installed.
  This is a pre-existing host-dependent test defect, not caused by this feature; cycle 3 fixes the test's hermeticity because it stops the suite before the new Orca cases run.
- full profile suite: not run here, left to CI.
- commit: `54c0b928` (planning commit, no behavior change).

Method notes:

- `tests/fm-backend-orca.test.sh` and `tests/fm-bootstrap.test.sh` have no per-test selector, so each red below was observed by running only the named test function through a scratch wrapper that sources the same file; nothing in the wrapper is committed.
- The harness stops a test function at its first failing assertion, so each red names the first assertion that failed.
- Every cycle wrote its tests first and ran them against the code as it stood.
- The three cycles are committed together in one implementation commit, so git history alone does not show test-first order; this log is the evidence.

## Cycle 1: repository kind and the folder refusal (U1, U2, U3, U4, A1)

- tests (new): `test_json_get_reads_repo_kind` (U1, U2), `test_repo_ensure_refuses_a_folder_repo` (U3), `test_repo_ensure_accepts_git_and_kindless_repos` (U4), `test_spawn_refuses_a_folder_kind_repo_before_any_mutation` (A1)
- red against the unchanged adapter:
  - U1 `not ok - repo-kind should read result.repo.kind, got ''`
  - U3 `not ok - repo_ensure should refuse a folder-kind repository, got 'repo-folder'`
  - A1 `not ok - the spawn refusal should name the per-task --backend escape hatch (missing: '--backend')`, with the spawn output ending `error: orca worktree create did not return a worktree id for fm-orcafolderz9`, so the spawn went on into worktree creation
  - U4 passed immediately: it pins existing behavior (a registered git or kindless repository is used as before) as a characterization guard for the change, not a new behavior.
- green: `fm_backend_orca_json_get` gained `repo-kind`; `fm_backend_orca_repo_ensure` reads it from the `repo show` result and refuses `folder` before printing an id. All four tests pass.
- refactor: none.

## Cycle 2: CLI discovery (U5, U6, U7, U8, U9, U10, U11, A2)

- tests (new): `test_tool_check_resolution_order` (U5-U8), `test_tool_check_skips_unusable_candidates` (U9), `test_tool_check_refusal_is_actionable` (U10), `test_worktree_create_uses_a_cli_found_off_path` (U11), `test_spawn_finds_the_orca_cli_under_orca_cli_bin_dir` (A2)
- red against the unchanged adapter:
  - U6 `not ok - a CLI only under ORCA_CLI_BIN_DIR should be found and run, ran '' (rc 1): error: backend=orca selected but the 'orca' CLI is not installed`
  - U9 `not ok - an ORCA_CLI_BIN_DIR that is empty should fall through to ~/.orca/cli/bin, ran '' (rc 1)`
  - U10 `not ok - the refusal should name PATH (missing: 'PATH')`
  - U11 and A2 failed with the same "not installed" refusal.
- green: `fm_backend_orca_tool_check` resolves the CLI and prepends a hit to `PATH`; `fm_backend_orca_worktree_create` calls it in its own shell.
- deliberate mutant: removing the `fm_backend_orca_tool_check` call from `fm_backend_orca_worktree_create` turns U11 red with `orca: command not found` at the bare `orca worktree create`, so the test does guard the command-substitution case; the call was restored.
- the existing `test_kill_refuses_when_the_orca_cli_is_absent` now pins `HOME` and `ORCA_CLI_BIN_DIR`, because the new fallback would otherwise find the operator's real CLI.
- refactor: none.

## Cycle 3: bootstrap resolution and install hint (A3, A4, A5)

- tests (new): `test_orca_backend_resolves_the_cli_from_orca_cli_bin_dir` (A3), `test_orca_install_hint_is_platform_aware` (A4, A5)
- red against the unchanged scripts:
  - A3 `not ok - bootstrap should not report orca missing when its CLI is under ORCA_CLI_BIN_DIR (unexpected: 'MISSING: orca')`
  - A4 `not ok - the Linux hint must not offer Homebrew (unexpected: 'brew install orca')`
  - A5 passed immediately for the Darwin half of the same test, which pins the unchanged macOS hint.
- green: `fm_backend_required_tool_available` routes `orca:orca` through the adapter tool check; `install_cmd` gives Homebrew on macOS and shim guidance elsewhere.
- `test_orca_backend_gates_orca_tool_only_when_selected` no longer hard-codes the platform-specific hint and pins `HOME` and `ORCA_CLI_BIN_DIR`.
- `test_session_provider_backends_gate_own_cli_not_tmux` hides the session CLI from the base path, fixing the baseline defect above.
- refactor: none.

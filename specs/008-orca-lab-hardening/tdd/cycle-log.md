# TDD cycle log: Orca Live Lab Hardening

## Cycle 1 - launcher pins HOME and drops agent-config pointers (O1, O2)

- RED: `bash tests/fm-backend-orca-lab-guard.test.sh` failed at `L1: the CLI runs with the lab home, not the operator's HOME (missing: 'HOME=<lab home>')`.
  The fake CLI printed the caller's `HOME` and all eight agent-config pointers unchanged, so the failure is the real hazard, not a test typo.
- Tests written first in the same working tree before any change to `tests/orca-lab-safety.sh`.

## Cycle 2 - runtime PATH builder and agent-free check (O3), config-path check (O4)

- RED: the same run reaches these cases only after Cycle 1 passes; `orca_lab_runtime_path`, `orca_lab_assert_path_agent_free`, and `orca_lab_paths_under_home` do not exist yet (command not found).

## Cycle 1 and 2 - GREEN

- GREEN: `orca_lab_validate_home`, `orca_lab_require_fresh` (factored out of the data-directory check, message unchanged), `orca_lab_agent_config_paths`, the pinned `orca_lab_write_launcher`, `orca_lab_agent_binaries`, `orca_lab_runtime_path`, `orca_lab_assert_path_agent_free`, and `orca_lab_paths_under_home` in `tests/orca-lab-safety.sh`.
- `bash tests/fm-backend-orca-lab-guard.test.sh` exits 0 with the four new `L1` lines.
- REFACTOR (green): the lane wiring in `tests/fm-backend-orca-smoke.test.sh` (launcher home argument, guarded runtime PATH, H1 assertion) and the header comments.
- Live: `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1 tests/fm-backend-orca-smoke.test.sh` printed `passed=44 findings=6`, exit 0, with `ok - H1: every agent hooks status config path lies inside the lab home`.
  Before this change the same lane printed `passed=43`, so H1 is the one added assertion and the 6 findings are the pre-existing ones.

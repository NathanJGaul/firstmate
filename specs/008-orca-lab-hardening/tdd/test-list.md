# Test list: Orca Live Lab Hardening

All tests are in `tests/fm-backend-orca-lab-guard.test.sh` (acceptance runs the public library functions and the lane entry point with no Orca).

## Outer

- O1 (US1.1, US1.5): the written launcher gives the CLI the lab HOME and no agent-config pointer, from a caller carrying the operator HOME.
- O2 (US1.2-4): the launcher write refuses every unpinned or unsafe home and writes nothing.
- O3 (US2.1-3): the runtime PATH holds no agent and the checker refuses agent directories and cwd-relative entries.
- O4 (US3.1): the config-path check accepts paths inside the lab home and refuses one outside.

## Inner

- I1: orca_lab_validate_home refuses empty, equal-to-HOME, root, ~/.orca, ~/.claude, inside ~/.codex, non-empty; accepts a fresh temp directory.
- I2: orca_lab_runtime_path output shape.
- I3: orca_lab_assert_path_agent_free names the entry and agent.
- I4: orca_lab_paths_under_home handles absent configPath fields and prefix-sibling directories (`home-evil` is not inside `home`).

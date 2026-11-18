# Convergence: Orca Adapter Hygiene

## Status

Merge-ready from the code side, pending the delivery pipeline.
All planned tasks T001-T020 are built; no unbuilt work remains.

## What changed

- `bin/backends/orca.sh`: `repo-kind` JSON field; folder refusal in `fm_backend_orca_repo_ensure`; CLI resolution in `fm_backend_orca_tool_check`; a tool check at the top of `fm_backend_orca_worktree_create`.
- `bin/fm-backend.sh`: `orca:orca` required-tool detection uses the adapter's resolution.
- `bin/fm-bootstrap.sh`: platform-aware `orca` install hint.
- `tests/fm-backend-orca.test.sh`, `tests/fm-bootstrap.test.sh`: new behavior tests, hermetic `HOME` and `ORCA_CLI_BIN_DIR` pinning, and the herdr base-path fix.
- `docs/orca-backend.md`: resolution order and folder refusal.

## Evidence

See `tdd/verification.md` for suite results, lint, mutant evidence, and the documentation audit.

## Remaining risk and open items

- Live behavior of a real Orca on a folder repository and the real `repo show` shape of `kind` are not proven; they belong to the lab slice of the evaluation plan.
- `docs/verification/runtime-backends.md` is unchanged because no live evidence was gathered.
- The full profile suite is left to CI.

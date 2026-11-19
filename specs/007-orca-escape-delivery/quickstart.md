# Quickstart: validating Orca Escape and Ctrl+U delivery

Prerequisites: a checkout of this branch, `bash`, `node`, `git`, `jq`, and `tmux`; the portable tests use a fake `orca` on the path.

1. Adapter and gate: `bin/fm-test-run.sh tests/fm-backend-orca.test.sh`.
2. Control plane and `fm-send`: `bin/fm-test-run.sh tests/fm-control.test.sh`.
3. Lint and docs: `bin/fm-lint.sh` and `bin/fm-doc-audience-check.sh`.
4. Live proof, opt-in, on a host with the Orca headless runtime installed: `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1 tests/fm-backend-orca-smoke.test.sh`.
   It starts its own runtime and never touches the operator's.

Steps 1 to 3 prove Firstmate's side.
Step 4 proves the bytes reach a real Orca terminal and prints the runtime's version and capability list.

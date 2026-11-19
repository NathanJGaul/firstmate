# Quickstart: Orca Spare Terminal

```sh
bin/fm-test-run.sh tests/fm-backend-orca.test.sh
bin/fm-test-run.sh tests/fm-spawn-orca-worktree.test.sh
bin/fm-test-run.sh tests/fm-teardown-endpoint-safety.test.sh
bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh
bin/fm-lint.sh
env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1 tests/fm-backend-orca-smoke.test.sh
```

The last command is the opt-in live lab.
It starts its own isolated runtime and never touches the operator's Orca.
After a spawn it asserts exactly one live terminal for the task worktree, and after teardown it asserts zero leftovers.

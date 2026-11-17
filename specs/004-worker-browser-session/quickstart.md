# Quickstart: Validating Per-Worker Browser Sessions

## Prerequisites

- A checkout of this branch with `bash`, `git`, `tmux`, `lsof`, and `shellcheck` available.
- No real `chrome-devtools-axi` is needed; the tests use a fake.

## Run the focused tests

```sh
bin/fm-test-run.sh tests/fm-spawn-compact-adviser-disable.test.sh
bin/fm-test-run.sh tests/fm-teardown.test.sh
```

Expected: every test prints `ok`, including the new per-worker browser session cases.

## Run the runner inventory guard and lint

```sh
bin/fm-test-run.sh --check-coverage
bin/fm-lint.sh
bin/fm-doc-audience-check.sh
```

Expected: all three exit 0.

## Observe the behavior by hand

1. Spawn a ship against a fake pane and read the launch text it staged; it contains `export CHROME_DEVTOOLS_AXI_SESSION=<task id>;`.
2. Run that launch with `chrome-devtools-axi` replaced by a script that prints its session variable; it prints the task id.
3. Clean the task up with a fake `chrome-devtools-axi` first on `PATH` that logs its arguments and session variable; the log has exactly one `stop` line for the task id and none for `default`.

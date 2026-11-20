# Cycle Log: Pinned Lint Tools Visible to the No-Mistakes Pipeline

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

Run from the starting commit `55bf3486` before any edit with `bin/fm-test-run.sh tests/fm-lint.test.sh tests/fm-lint-workflows.test.sh`.

- No pinned tools on the search path: both suites exit 1 with the ShellCheck and actionlint "not found" messages, which is the reported defect reproduced on this host.
- Pinned tools staged on the search path from a scratch directory: `tests/fm-lint-workflows.test.sh` exit 0; `tests/fm-lint.test.sh` exit 1 with a single failure, `the fallback attempts lost per-root RSS reporting: unavailable`, because this host has no `/usr/bin/time`.
- full profile suite: not run here, left to CI
- commit: `55bf3486`

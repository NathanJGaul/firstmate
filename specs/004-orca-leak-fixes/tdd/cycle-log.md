# Cycle Log: Orca Backend Leak Fixes

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- suite: `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` -> `FM_TEST_SUMMARY total=1 failed=0` (114 s)
- suite: `bin/fm-test-run.sh tests/fm-teardown-endpoint-safety.test.sh` -> `FM_TEST_SUMMARY total=1 failed=0` (233 s)
- full profile suite: not run here, left to CI
- commit: `af20b2c9`
- recorded: cycle 0, before any change

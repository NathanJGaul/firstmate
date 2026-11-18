# Quickstart: Orca Live Test Lab

1. Guard test, no Orca needed: `bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh`.
2. Live lane on a host with the headless runtime: `FM_ORCA_LIVE_E2E=1 bin/fm-test-run.sh tests/fm-backend-orca-smoke.test.sh`.
3. Expected: `ok -` lines for hard assertions, `# observe:` and `# finding:` lines for shapes, `# not run:` for assertion 11, and a final inventory of zero leftovers.
4. Without the opt-in variable the lane prints `skip: live: opt-in; set FM_ORCA_LIVE_E2E=1 to run`.

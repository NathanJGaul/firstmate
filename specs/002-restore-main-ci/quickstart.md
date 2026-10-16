# Quickstart: Validate Restore Main CI

## Prerequisites

Run from the task worktree.
Install scratch copies of Pi 1.2.0 and 1.3.0 and `typescript` into a prefix outside the worktree (`npm install -g --prefix <dir> ...`).
For each Pi release set `NPM_CONFIG_PREFIX=<dir>/p<version>` and put `<dir>/p<version>/bin` and `<dir>/ts/bin` on `PATH` so the tests find the package, `pi`, and `tsc`.
For the bash 5.2 runs use an `ubuntu:24.04` container with `jq git tmux procps python3` and the worktree mounted read-only.

## Scenarios

1. Pi typecheck and run-start handling, for Pi 1.2.0 and 1.3.0:
   `bin/fm-test-run.sh tests/fm-pi-primary-types.test.sh`
   `bin/fm-test-run.sh tests/fm-pi-branch-extension.test.sh`
   `bin/fm-test-run.sh tests/fm-pi-watch-extension.test.sh`
   Expect exit 0 and no gate skip.
2. Contributions slow head:
   `bin/fm-test-run.sh tests/fm-contributions.test.sh`
   Expect `ok - ... slow head ...` is absent as a failure and the file exits 0.
   Repeat several runs in parallel to check the shared-clock race stays fixed.
3. Calm fixtures, for Pi 1.2.0 and 1.3.0:
   `bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh`
   `FM_LIVE=1 bin/fm-test-run.sh tests/fm-calm-pi-queue-retention-live-e2e.test.sh`
   Expect exit 0.
4. Wake-drain interruption:
   `bin/fm-test-run.sh tests/fm-wake-queue.test.sh`
   Then run the fine-grained TERM timing fuzz 1500 times in the bash 5.2 container and expect no run with status 0 or a trap parse error.
5. Whole-change gates:
   `bin/fm-lint.sh`
   `bin/fm-test-run.sh --check-coverage`
   `bin/fm-doc-audience-check.sh`

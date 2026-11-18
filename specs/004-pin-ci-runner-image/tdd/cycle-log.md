---
feature: 004-pin-ci-runner-image
profile: .specify/memory/tdd-profile.md
---

# TDD Cycle Log: Pin the CI Runner Image

Commit order is the test-first evidence: `d1d58ee5` (red guard test) precedes `cd2ac17c` (the pin).

## Cycle 1 - A1, U1, U2: Linux jobs pin a runner image

**Red** (commit `d1d58ee5`, `bin/fm-test-run.sh tests/fm-ci-workflow.test.sh`, exit 1, failing for the right reason):

```
not ok - these CI Linux jobs do not pin a runner image:
lint: ubuntu-latest
test-coverage: ubuntu-latest
tests-portable-parallel-1: ubuntu-latest
tests-portable-parallel-2: ubuntu-latest
tests-portable-serial: ubuntu-latest
tests-herdr: ubuntu-latest
tests-timing-aggregate: ubuntu-latest
invariants: ubuntu-latest
```

The macOS job was not named, which is U2.

**Green** (commit `cd2ac17c`): the eight labels became `ubuntu-24.04`; the same command exits 0 with `ok - every ci.yml Linux job pins its runner image` and all other cases unchanged.

**Refactor**: none needed; the helper is one self-contained function beside its siblings.

**Mutant**: restoring `ubuntu-latest` on `tests-herdr` alone made the test exit 1 naming `tests-herdr: ubuntu-latest`; restoring the pin returned it to green.

## Cycle 2 - A2: the fake Pi host holds the pending-bash list

**Red** (before commit `7055ba40`): `tests/fm-calm-pi-extension.test.sh` against Pi 1.5.2, in an Ubuntu 26.04 container and natively on the maintainer host (the mutant run below), exit 1:

```
not ok - Pi Calm queued operational rows: file:///.../pi-coding-agent/dist/modes/interactive/interactive-mode.js:4009
        for (const component of this.pendingBashComponents) {
TypeError: this.pendingBashComponents is not iterable
    at InteractiveMode.updatePendingMessagesDisplay
```

The failure is the one the hosted jobs reported on main and on PR 7.

**Green** (commit `7055ba40`, one added field): the whole file exits 0 natively with Pi 1.5.2 and Chromium (no skip), and with Pi 1.3.0.
The queued-operational-rows case passes in the 26.04 container as well; that container has no Chrome, so its run stops later at the rendered-export Chrome requirement, which is unrelated to this change.

**Refactor**: none.

**Mutant**: deleting the field again reproduced the exact `TypeError` natively (exit 1); restoring it returned to green.

## Not a behavior cycle

The documentation line (FR-004) and the workflow comment (FR-003) are prose; see `tdd/test-list.md` for why no test pins them.

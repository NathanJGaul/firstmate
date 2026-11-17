# Feature Specification: Pin the CI Runner Image

**Feature Branch**: `fm/firstmate-main-ci-red`

**Created**: 2026-11-17

**Status**: Approved by the task brief

**Input**: User description: "Get firstmate main's CI green again. Its hosted CI has failed on every push since 2026-10-16, so PRs such as the Orca documentation fix can land green instead of with waived checks. Seven jobs fail on main and on PR 7: Behavior portable parallel 1, serial 2, serial 3, serial 5 (cancelled by the provider), serial 6, serial 8, and Behavior tests (Herdr)."

## Overview

Main has been red on every push since the hosted `ubuntu-latest` label moved from Ubuntu 24.04 to Ubuntu 26.04 (image 20261111.196.1 on the red runs).
Each failing job was reproduced in an Ubuntu 26.04 container that mirrors the hosted image, and each failure was classified (the private classification record lives with the task, outside the repository).
Ubuntu 26.04 ships Rust uutils coreutils 0.10.0 as the default userland, which differs from GNU coreutils in four ways this suite meets:

- A symlink to `sleep` under another name is refused by the multicall binary, so agent-named stand-in processes never exist.
- A closed standard output is reopened as `/dev/null` by `env`, so "the drain cannot print" cases print into the void.
- `mkdir` can report success to more than one concurrent caller of the same path, so sequence claims repeat.
- The hosted image carries no `tsc`, so the strict Pi typecheck gate fails instead of running.

The upstream project pinned every Linux CI job to `ubuntu-24.04` on 2026-10-26 and its main CI has been green since.
The last fork main run on `ubuntu-24.04` (2026-10-16) failed one flaky script only.
One failure is independent of the operating system: Pi 1.5.x iterates `this.pendingBashComponents` when it updates its pending-message display, and the Calm Pi test's fake Pi host does not define it.

This feature restores the last known-good runner image with a guard so the floating label cannot return unnoticed, and fixes the fake host.
Making the suite and the product robust on uutils hosts is recorded as follow-up work, not built here.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - CI runs on a known runner image (Priority: P1)

A maintainer opens a pull request and expects its hosted checks to run on the same operating system that last produced green results, not on whatever image GitHub moves the floating label to.

**Why this priority**: Six of the seven failing jobs fail only because of the 26.04 userland, and a floating label can break main again without any change to the repository.

**Independent Test**: Parse `.github/workflows/ci.yml` and read each Linux job's runner label.

**Acceptance Scenarios**:

1. **Given** the CI workflow, **When** each Linux job's runner label is read, **Then** every one names `ubuntu-24.04`.
2. **Given** a Linux job whose runner label is the floating `ubuntu-latest`, **When** the workflow contract test runs, **Then** it fails and names the job.
3. **Given** the `macos-latest` job, **When** the contract test runs, **Then** it is not required to carry a Linux image.
4. **Given** the timing documentation, **When** it names the image the balance hints came from, **Then** it names `ubuntu-24.04`.

---

### User Story 2 - The Calm Pi extension test runs against current Pi (Priority: P1)

A maintainer runs the Calm Pi extension test against the newest published Pi package.

**Why this priority**: It fails on every operating system today with `TypeError: this.pendingBashComponents is not iterable`, so the queued-operational-rows behavior it pins is unverified.

**Independent Test**: Run `tests/fm-calm-pi-extension.test.sh` with Pi 1.5.2 installed.

**Acceptance Scenarios**:

1. **Given** Pi 1.5.2 installed, **When** the queued-operational-rows case builds its fake Pi host, **Then** the host defines the pending-bash list Pi iterates and the case reaches its assertions.
2. **Given** an older Pi that never reads the list, **When** the same case runs, **Then** the extra property is ignored and the case still passes.

### Edge Cases

- The compliance workflow `no-mistakes-required.yml` runs one trivial job that does not depend on the userland, and stays unchanged.
- The Herdr, shard, lint, coverage, invariant, and aggregate jobs all pin together because any of them can meet the same userland difference.
- Pi stays unpinned in CI on purpose so Pi drift stays visible; this feature does not change that.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every Linux job in `.github/workflows/ci.yml` MUST run on `ubuntu-24.04`.
- **FR-002**: A contract test MUST fail, naming the job, when a Linux job in `ci.yml` uses a floating runner label.
- **FR-003**: `ci.yml` MUST carry one comment stating why the image is pinned and what must be true before it moves.
- **FR-004**: `docs/fm-test-portable-shards.md` MUST name the pinned image as the source of its balance hints.
- **FR-005**: The Calm Pi test's fake Pi host MUST define the pending-bash list that current Pi iterates.
- **FR-006**: No assertion MAY be weakened, skipped, or deleted to reach green.

### Key Entities

- **Runner label**: the `runs-on` value of a CI job.
- **Fake Pi host**: the stand-in object the Calm Pi test builds from Pi's real `InteractiveMode` prototype.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The workflow contract test is red before the pin and green after it.
- **SC-002**: The Calm Pi extension test passes with Pi 1.5.2 in Ubuntu 24.04 and Ubuntu 26.04 containers.
- **SC-003**: The hosted checks on the delivery PR are green, or the failing job is named with its evidence.

## Assumptions

- GitHub keeps the `ubuntu-24.04` image available; the pin is revisited when the follow-up work below lands.
- Hosted `ubuntu-24.04` provides `tsc`; the 2026-10-16 run executed the strict Pi typecheck there.

## Out of Scope (follow-up work)

- Agent-named stand-ins that survive multicall coreutils (upstream commit 329ad4ed) and the two closed-standard-output tests running their script through `bash`.
- Making the `mkdir`-based claims (`fm_remote_job_next_seq`, the remote job worker lock and claim, the AFK launch lock, the busy-event lock) exclusive on uutils hosts, which changes a lock protocol and needs a design decision.
- Unproven single-run failures: the tmux smoke window, the remote secondmate lifecycle watcher bound, and the Herdr presentation recovery lock.

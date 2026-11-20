# Feature Specification: Pinned Lint Tools Visible to the No-Mistakes Pipeline

**Feature Branch**: `fm/firstmate-pipeline-linter-provisioning`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Every firstmate pipeline run reports that lint was skipped or approved because ShellCheck is not installed where the no-mistakes pipeline agents run, so lint rests on local runs by workers.
Provision pinned ShellCheck and actionlint where the pipeline's agents can see them.

## Overview

The shared no-mistakes daemon runs the tracked `commands.lint` (`bin/fm-lint.sh`) with its own process environment.
That environment has a fixed search path made of user and system directories and no version-manager shims, so the pinned ShellCheck and actionlint that workers use locally are invisible to it.
Of 176 recorded pipeline runs, 25 show the lint step stopping with "ShellCheck not found" and the agent fix rounds that follow cannot repair a missing tool.
CI is unaffected because it installs both pinned tools per job with checksum-verified installers.

The daemon is shared by every lane, so it is never restarted, updated, or given a new environment.
The tools must instead become findable by the lint entry points themselves, from a location every process of the same user can reach, and provisioned by the same checksum-pinned installers CI uses.

## User Scenarios & Testing

### User Story 1 - The pipeline's lint step finds the pinned tools (Priority: P1)

**Why this priority**: This is the reported defect.

**Independent Test**: Run the lint entry point from an empty environment that carries only a daemon-like search path and a home directory, after provisioning.

**Acceptance Scenarios**:

1. **Given** the pinned tools are provisioned in the managed tool directory and neither is on the search path, **When** `bin/fm-lint.sh` runs from a clean environment, **Then** it resolves the pinned ShellCheck, reports the pinned version, and runs, including the workflow lint with the pinned actionlint.
2. **Given** a pinned tool is in the managed directory and an off-pin tool is on the search path, **When** lint runs, **Then** the pinned managed tool is used; a pinned tool on the search path with no managed copy is also accepted.
3. **Given** the managed directory holds a build that is not the pinned version, **When** lint runs, **Then** it refuses naming the pin, never lint under another version.

### User Story 2 - One command provisions both tools, safely and repeatably (Priority: P1)

**Why this priority**: Without a single provisioning step the machine stays unprovisioned.

**Independent Test**: Run the provisioning command twice against a temporary tool directory with stubbed downloads.

**Acceptance Scenarios**:

1. **Given** an empty managed directory, **When** the provisioning command runs, **Then** both pinned tools are installed through the existing checksum-verified installers and each reports its pinned version.
2. **Given** both tools are already at the pinned versions, **When** it runs again, **Then** nothing is downloaded.
3. **Given** a download fails its checksum, **When** it runs, **Then** it exits non-zero and installs nothing from that archive.
4. **Given** a `--check` request, **When** it runs, **Then** it reports each tool's status and exits non-zero if either is missing or off-pin, changing nothing.

### User Story 3 - A missing tool says exactly how to fix it (Priority: P2)

**Acceptance Scenarios**:

1. **Given** neither location has the tool, **When** lint runs, **Then** it exits 1 and names the one provisioning command and the managed directory.

### Edge Cases

- The managed directory location is overridable for tests and unusual homes, and an override pointing nowhere behaves like an absent directory.
- With no home directory in the environment and no override, the managed location cannot be derived; the lookup treats the directory as absent rather than failing the lint with an unrelated error.
- A managed file that exists but is not executable is ignored.
- The daemon, its configuration, and its environment are never touched by provisioning.

## Requirements

### Functional Requirements

- **FR-001**: `bin/fm-lint.sh` and `bin/fm-lint-workflows.sh` MUST resolve ShellCheck and actionlint from one managed pinned-tool directory when its tool reports the pin and otherwise from the search path, refusing any resolved tool that is off-pin.
- **FR-002**: The managed directory MUST default to a per-user location that the shared daemon process can reach, and MUST be overridable with `FM_LINT_TOOLS_DIR`.
- **FR-003**: Version enforcement MUST be unchanged: a resolved tool that is not the exact pin is refused, wherever it was found.
- **FR-004**: One owner MUST define the managed directory location, and both lint entry points and both installers MUST use it.
- **FR-005**: `bin/fm-install-shellcheck.sh` and `bin/fm-install-actionlint.sh` MUST install into the managed directory when given no destination, and keep their explicit-destination behavior.
- **FR-006**: A provisioning command MUST install both pinned tools into the managed directory through those installers, skip a tool already at its pin, support `--check`, and be safe to repeat.
- **FR-007**: The missing-tool message of both lint entry points MUST name the provisioning command and keep naming the pinned installer.
- **FR-008**: Provisioning and lookup MUST NOT stop, restart, update, or reconfigure the no-mistakes daemon and MUST NOT require a change to its environment.
- **FR-009**: Contributor documentation MUST describe the managed directory, the provisioning command, and the reason the pipeline needs it.

### Key Entities

- **Managed tool directory**: the per-user directory holding the pinned ShellCheck and actionlint binaries.
- **Pin**: the exact version each lint entry point enforces (`--required-version`).

## Success Criteria

- **SC-001**: From an empty environment carrying only a daemon-like search path, after provisioning, the repository's lint entry point completes using the pinned versions with zero "not found" outcomes.
- **SC-002**: A second provisioning run performs no downloads.
- **SC-003**: Every existing lint and installer behavior test still passes unchanged in outcome.
- **SC-004**: A reader of the contributor docs can provision a machine with one command.

## Assumptions

- The daemon runs as the same user as the workers and its home directory is the same, which is true on the supported operator machines.
- The first provisioning run on a machine is an operator step performed outside this change, because it writes under the user's cache directory.
- Network access to the official release hosts is available when provisioning, as in CI.

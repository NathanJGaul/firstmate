# Feature Specification: Orca Adapter Hygiene

**Feature Branch**: `fm/firstmate-orca-adapter-hygiene`

**Created**: 2026-11-18

**Status**: Draft

**Input**: Reject folder-kind repositories on Orca early with a message naming the per-task `--backend` escape hatch (slice 5, P1-C, CC-4 option a), and resolve the `orca` CLI from `PATH`, then `$ORCA_CLI_BIN_DIR`, then `~/.orca/cli/bin`, with an actionable refusal and a corrected Linux install hint (slice 7, P1-E).
These are slices from section 5.2 of the Orca evaluation plan.

## Overview

Two Orca-backend gaps remain in the adapter.

First, Orca registers some projects, including the firstmate home itself, as a folder rather than a git repository.
The adapter accepts any registered repository without looking at its kind, so a spawn against a folder-registered project proceeds into a worktree creation that Orca cannot serve as a git worktree.
This feature makes the adapter refuse that case before any worktree is created, and tell the operator the per-task escape hatch.

Second, the `orca` CLI is on `PATH` only inside Orca's own terminals.
In any other shell, such as a restarted primary or a worker, the adapter reports the CLI as not installed, and bootstrap tells a Linux operator to run `brew install orca`.
This feature makes the adapter find the CLI where Orca puts it, refuse with an actionable message when it truly is absent, and give Linux operators a correct hint.

## User Scenarios & Testing

### User Story 1 - A folder-registered project is refused early on Orca (Priority: P1)

The operator dispatches a task on the Orca backend for a project Orca has registered as a folder.

**Why this priority**: Without the check the spawn fails or misbehaves deep inside worktree creation, and the operator is never told that another backend is the way out.

**Independent Test**: Spawn and call the adapter against a fake Orca whose `repo show` reports `kind` as `folder`, then read the fake's command log.

**Acceptance Scenarios**:

1. **Given** Orca reports the project's repository as a folder, **When** a task is spawned with `--backend orca`, **Then** the spawn fails before any worktree is created, and the message says the project is a folder repository and names the per-task `--backend` option as the way to run it on another backend.
2. **Given** that refusal, **When** the command log is read, **Then** it holds no `repo add`, `repo rm`, `repo set`, `worktree create`, or `terminal` call, so the operator's Orca registration is untouched.
3. **Given** Orca reports the repository as `git`, or reports no kind at all, **When** a task is spawned, **Then** the repository id is used exactly as before.
4. **Given** the repository is not registered, **When** a task is spawned, **Then** it is registered with `repo add` exactly as before.

---

### User Story 2 - The Orca CLI is found outside Orca terminals (Priority: P1)

The operator or a worker runs Firstmate on the Orca backend from a shell that is not an Orca terminal.

**Why this priority**: A restarted primary, a daemon, or a worker cannot operate Orca tasks at all while the CLI is not found.

**Independent Test**: Call the adapter and bootstrap with a fake `orca` placed only in one candidate directory, with `PATH` and `HOME` pinned to throwaway values.

**Acceptance Scenarios**:

1. **Given** `orca` is on `PATH`, **When** the adapter runs, **Then** that CLI is used, even if the other locations also hold one.
2. **Given** `orca` is not on `PATH` but is in `$ORCA_CLI_BIN_DIR`, **When** the adapter runs, **Then** that CLI is used for every Orca call, including a whole worktree creation.
3. **Given** `orca` is on neither but is in `~/.orca/cli/bin`, **When** the adapter runs, **Then** that CLI is used.
4. **Given** `orca` is in both `$ORCA_CLI_BIN_DIR` and `~/.orca/cli/bin`, **When** the adapter runs, **Then** the `$ORCA_CLI_BIN_DIR` one is used.
5. **Given** `orca` is in none of the three places, **When** the adapter runs, **Then** it refuses and the message names all three places and how to fix it, and it makes no Orca call.
6. **Given** the bootstrap check runs with the Orca backend selected and the CLI only in `$ORCA_CLI_BIN_DIR`, **When** it reports missing tools, **Then** it does not report `orca` missing.

---

### User Story 3 - The Linux install hint is correct (Priority: P2)

An operator on Linux has the Orca backend selected and no CLI.

**Why this priority**: The current hint is a macOS command with no Linux meaning, so it sends the operator the wrong way.

**Independent Test**: Run bootstrap with a fake `uname` reporting each platform and no `orca`.

**Acceptance Scenarios**:

1. **Given** the host is not macOS, **When** bootstrap reports `orca` missing, **Then** the hint does not offer `brew install orca` and instead says to install Orca, start it once, and put `~/.orca/cli/bin` on `PATH` or export `ORCA_CLI_BIN_DIR`.
2. **Given** the host is macOS, **When** bootstrap reports `orca` missing, **Then** the hint is unchanged.

## Edge Cases

- `kind` is absent from `repo show`: treated as not a folder, so older Orca responses keep working.
- `repo show` fails or reports no repository: the repository is registered with `repo add`, as before.
- `$ORCA_CLI_BIN_DIR` is unset, empty, missing, or lacks an executable `orca`: the next location is tried.
- A non-executable file or a directory named `orca` in a candidate directory is not the CLI.
- A newly added repository whose registration result reports `folder` is out of scope; this feature checks only the registration Orca already holds.

## Requirements

### Functional Requirements

- **FR-001**: The repository-ensure step MUST read `kind` from the `repo show` result and MUST refuse when it is `folder`.
- **FR-002**: The folder refusal MUST name the project, say Orca holds it as a folder, and name the per-task `--backend` option as the escape hatch.
- **FR-003**: The folder refusal MUST NOT issue any Orca call that changes registration, creates a worktree, or touches a terminal.
- **FR-004**: A repository reported as `git`, or with no kind, MUST behave exactly as before.
- **FR-005**: The tool check MUST resolve the CLI from `PATH`, then `$ORCA_CLI_BIN_DIR`, then `~/.orca/cli/bin`, in that order, accepting only an executable regular file named `orca`.
- **FR-006**: When the CLI is found off `PATH`, every later Orca call in the same adapter entry point MUST use it.
- **FR-007**: When the CLI is found nowhere, the refusal MUST name all three locations and the fix, and MUST NOT call Orca.
- **FR-008**: Bootstrap's required-tool detection for the Orca backend MUST use the same resolution, so a resolvable CLI is not reported missing.
- **FR-009**: Bootstrap's install hint for `orca` MUST stay the Homebrew command on macOS and MUST describe the Orca-installed CLI shim on every other platform.

### Key Entities

- **Orca CLI location**: one of three candidate directories searched in a fixed order for an executable `orca`.
- **Repository kind**: the `git` or `folder` classification Orca holds for a registered project.

## Success Criteria

- **SC-001**: A spawn for a folder-registered project exits non-zero before worktree creation with a message naming `--backend`, and the fake Orca log shows no mutating call.
- **SC-002**: With the CLI only under `$ORCA_CLI_BIN_DIR` or only under `~/.orca/cli/bin`, a worktree creation through the adapter completes against the fake Orca.
- **SC-003**: Bootstrap on a non-macOS host never prints `brew install orca`.

## Assumptions

- `orca repo show --json` reports `kind` on the repository object (`result.repo.kind`) or directly on the result, as `repo list` does; the adapter reads both and treats an absent kind as not a folder.
- The live Orca runtime is not touched; behavior is proven against fake Orca fixtures only, and what a real folder repository does on `worktree create` stays a lab question.
- The shim directory `~/.orca/cli/bin` and the `ORCA_CLI_BIN_DIR` variable are as observed on Orca 1.4.261 and recorded in `docs/orca-backend.md`.

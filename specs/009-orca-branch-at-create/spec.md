# Feature Specification: Orca Branch At Create

**Feature Branch**: `fm/firstmate-orca-branch-at-create`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Name the ship branch when the Orca worktree is created instead of cleaning up the Orca-made one afterwards (slice N1 of the Orca agentic CLI scout report, section 6.2).

## Overview

Today an Orca-backed ship starts on a branch Orca invents (a prefixed default), while the brief tells the worker it is at a detached HEAD and must run `git checkout -b fm/<id> --`.
Teardown then detaches the worktree and force-deletes whatever branch the worker ended on with `git branch -D`, because Orca's safe `--delete-branch` cannot prove a squash-merged branch merged.
That force delete bypasses Orca's merged proof and, on a forced teardown, deletes unlanded work.

`orca worktree create` accepts `--branch <name>` and `--base-branch <ref>`.
Live on Orca 1.4.261 it names the branch exactly as given, with no user prefix, and a later `worktree rm --force --delete-branch` removes a merged branch and keeps an unmerged one (`preservedBranch`).
Orca renames a branch name that is already taken by adding a numeric suffix.

This feature passes the ship branch (the registered ship-branch prefix plus the task id) and the task base branch to `worktree create`, verifies the worktree really is on the requested branch, tells a ship worker the truth about its branch, and stops teardown from force-deleting the branch on Orca.
It does not touch scouts, secondmates, other backends, or any launch path.

## User Scenarios & Testing

### User Story 1 - An Orca ship starts on its own branch (Priority: P1)

The ship branch exists, with the right name, from the moment the worktree exists.

**Why this priority**: It removes the Orca-made branch and the cleanup that existed only to dispose of it.

**Independent Test**: Spawn a ship on a fake `orca` that records its arguments and builds a real worktree on the branch it is given, then read the recorded call and the worktree's branch.

**Acceptance Scenarios**:

1. **Given** a ship spawn on Orca with no branch prefix, **When** the worktree is created, **Then** `worktree create` receives `--branch fm/<id>` and the worktree is on `fm/<id>`.
2. **Given** a registered or explicit prefix `team/`, **When** the worktree is created, **Then** it receives `--branch team/<id>`, and an empty prefix gives the bare task id.
3. **Given** `--base-branch <name>` that exists only on origin, **When** the worktree is created, **Then** the spawn has fetched it and `worktree create` receives `--base-branch origin/<name>`; **Given** no base branch, **Then** no `--base-branch` is passed; **Given** a base branch origin cannot supply, **Then** the spawn refuses before any worktree is created.
4. **Given** a scout spawn on Orca, **When** the worktree is created, **Then** neither `--branch` nor `--base-branch` is passed.
5. **Given** Orca puts the worktree on a different branch than requested (a taken name gets a numeric suffix), **When** the spawn checks it, **Then** the spawn refuses, names both branches, and releases the worktree it just made.

---

### User Story 2 - A ship worker is told the truth about its branch (Priority: P1)

**Why this priority**: The old first action, `git checkout -b <branch> --`, fails on a worktree that already is on that branch, and the old setup sentence says detached HEAD.

**Independent Test**: Scaffold a ship brief, read its setup and first action, and run the first-action command in a detached repository and in one already on the branch.

**Acceptance Scenarios**:

1. **Given** a ship brief, **When** its first-action command runs at a detached HEAD, **Then** it creates and enters the ship branch exactly as before.
2. **Given** a ship brief, **When** its first-action command runs on a worktree already on the ship branch, **Then** it succeeds and changes nothing.
3. **Given** a ship brief, **When** a worker reads its setup, **Then** the setup says that an Orca-managed worktree already starts on the ship branch and every other worktree starts detached.
4. **Given** a brief with a base branch, **When** the spawn compares the Base branch lines, **Then** they still agree (the sentence the comparison reads is unchanged).

---

### User Story 3 - Teardown never force-deletes the branch on Orca (Priority: P1)

**Why this priority**: With the branch named at create, the force delete would destroy the one ref the delivery path depends on.

**Independent Test**: Tear down a landed and a forced unlanded ship on a fake `orca` and read the branch afterwards; then the same against the live lab.

**Acceptance Scenarios**:

1. **Given** an Orca ship teardown that passes every landed-work check, **When** it releases the worktree, **Then** the only branch deletion is Orca's `worktree rm --force --delete-branch`, and firstmate runs no `git branch -D`.
2. **Given** a forced teardown of an unlanded ship, **When** it completes, **Then** the branch still exists (Orca preserves a branch it cannot prove merged).
3. **Given** a landed ship in the live lab, **When** teardown completes, **Then** the branch is gone; **Given** an unlanded one forced, **Then** it is kept.

## Edge Cases

- Orca hands `--base-branch` to `git worktree add` verbatim, so a base that exists only on origin (the usual case) fails as a bare name; live on 1.4.261 the bare name returned `invalid reference` and `origin/<name>` after a fetch worked.
- A relaunch reuses its recorded worktree and creates none, so nothing changes (Orca relaunch is refused today anyway).
- A branch name Orca cannot honor (already taken) is a refusal after create, never a silent suffix: the worker and the task record would otherwise disagree about the branch.
- A scout promoted to a ship on Orca keeps the Orca-made scout branch; promotion's own branch step is unchanged.
- A squash-merged branch that Orca cannot prove merged is now kept locally after teardown; the remote branch and the PR are unaffected.
- The adapter keeps passing explicit `--repo id:` and never relies on the caller's own Orca environment.

## Requirements

### Functional Requirements

- **FR-001**: `fm_backend_orca_worktree_create` MUST accept an optional branch and an optional base branch and pass them as `--branch` and `--base-branch` to `orca worktree create`; with neither, the call MUST be unchanged.
- **FR-002**: `bin/fm-spawn.sh` MUST pass the ship branch (`<prefix><id>`) on a fresh ship spawn on Orca, MUST pass the task base branch as `origin/<base>` after fetching it when one is set (refusing before any create when the fetch fails), and MUST pass no branch for a scout, a secondmate, or a relaunch.
- **FR-009**: A refused `orca worktree create` MUST report Orca's own reason, which the adapter previously swallowed.
- **FR-003**: After the worktree exists, `bin/fm-spawn.sh` MUST refuse when a ship's worktree is not on the requested branch, naming both, and MUST release the worktree through the existing abort cleanup.
- **FR-004**: The ship brief's first action MUST succeed at a detached HEAD (creating the branch) and on a worktree already on the branch (changing nothing), and the brief MUST state the Orca case in its setup without changing the sentence `fm_brief_base_branches` reads.
- **FR-005**: The Orca arm of `bin/fm-teardown.sh` MUST NOT run `git branch -D` or detach the worktree; the branch is deleted only through `worktree rm --force --delete-branch`.
- **FR-006**: The behavior MUST be proven against the live lab: the branch equals the expected name, is deleted after a landed ship, and is kept after a forced unlanded one.
- **FR-007**: `docs/orca-backend.md`, `docs/verification/runtime-backends.md`, and any header that described the Orca-made branch MUST be corrected.
- **FR-008**: No other backend, launch path, control verb, or Orca capability gate changes.

## Success Criteria

- An Orca ship's branch equals `<prefix><id>` from creation, in the fake and in the lab.
- A worker told to create its branch on Orca no longer hits "already exists".
- Teardown on Orca never runs a forced branch delete.

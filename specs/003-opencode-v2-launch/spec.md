# Feature Specification: OpenCode v2 Worker Launch

**Feature Branch**: `fm/firstmate-opencode-v2-launch`

**Created**: 2026-11-14

**Status**: Implemented

**Input**: Worker launches on OpenCode must work on the installed OpenCode 2.2.5, whose command line and plugin loader differ from the verified 1.x surface.

## Overview

Firstmate's OpenCode worker launch targets the 1.x surface.
On OpenCode 2.2.5 it exits at the command line because the interactive launch rejects `--model`, and the permission, model, and effort settings it carries in `OPENCODE_CONFIG_CONTENT` are ignored.
Verification on this machine also showed that OpenCode 2.2.5 refuses to load a plugin that lacks a default export with an id, so the busy-state plugin the spawn writes into every OpenCode worktree never loads.
Without it the worker's busy and idle state stays frozen at the spawn seed.

## User Scenarios & Testing

### User Story 1 - A worker starts on OpenCode 2.2.5 (Priority: P1)

The operator dispatches a ship or scout task to the OpenCode harness.

**Independent Test**: Spawn against a fake pane and read the staged launch command and the task worktree.

**Acceptance Scenarios**:

1. **Given** an OpenCode spawn with a resolved model, **When** the launch command is staged, **Then** it passes `--auto` and `--prompt` with the launch brief, passes no `--model`, and sets no `OPENCODE_CONFIG_CONTENT`.
2. **Given** an OpenCode spawn with a resolved model, **When** the worktree is prepared, **Then** `.opencode/opencode.json` in that worktree carries exactly that model and is excluded from version control.
3. **Given** an OpenCode spawn with no model or the default model, **When** the worktree is prepared, **Then** no model pin is written and the launch is otherwise identical.
4. **Given** an OpenCode spawn with an effort, **When** the launch is built, **Then** the effort is recorded in task metadata and omitted from the launch, because OpenCode 2.2.5 has no known effort surface for this model family.
5. **Given** a worktree whose tracked files already include `.opencode/opencode.json`, **When** an OpenCode spawn needs a model pin, **Then** the spawn stops with an error instead of overwriting the project's file.
6. **Given** a relaunch of an OpenCode task, **When** the replacement is armed, **Then** the model pin matches the replacement's model.

### User Story 2 - Busy and idle state tracks the worker on OpenCode 2.2.5 (Priority: P1)

**Independent Test**: Load the generated plugin in a plain Node host as OpenCode 2.2.5 does and feed it the 2.2.5 session events.

**Acceptance Scenarios**:

1. **Given** the generated plugin, **When** OpenCode 2.2.5 loads it, **Then** it is a default export with an id and a setup function.
2. **Given** the 2.2.5 plugin context, **When** a session starts an execution, **Then** the task is classified busy, and **When** that session's execution succeeds, fails, or is interrupted, **Then** the task is classified idle and the turn-end marker is touched.
3. **Given** a child session that runs while the main session is busy, **When** the child's execution ends, **Then** the worker stays busy.
4. **Given** a scheduled retry, **When** it is reported for the latched session, **Then** the task stays busy.
5. **Given** OpenCode 1.x, **When** it loads the same file, **Then** the existing `session.status` and `session.idle` behavior is unchanged.

## Requirements

- **FR-001**: The OpenCode launch template MUST be `opencode --auto --prompt <brief>` with no `--model` and no `OPENCODE_CONFIG_CONTENT`.
- **FR-002**: The spawn MUST write the resolved model to `.opencode/opencode.json` in the task worktree and exclude it from version control; it MUST refuse to overwrite a tracked project file.
- **FR-003**: Effort for OpenCode MUST stay on the record-and-omit contract.
- **FR-004**: The busy-state plugin MUST load on OpenCode 2.2.5 and report busy and idle from `session.execution.*` and `session.retry.scheduled`, scoped to the latched worker session, while keeping 1.x behavior.
- **FR-005**: Other harness launch paths MUST be unchanged.
- **FR-006**: The OpenCode reference MUST record the verified 2.2.5 facts.

## Out of scope

Other harnesses, dispatch profile machinery, and the primary-side `fm-primary-*` OpenCode plugins.

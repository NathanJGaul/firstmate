# Feature Specification: Code Mode Scout Pilot

**Feature Branch**: `fm/firstmate-code-mode-scout-pilot`

**Created**: 2026-11-19

**Status**: Approved by the brief

**Input**: The captain accepted the Code Mode scout's recommendations on 2026-11-19 (report section 8): pilot Code Mode on scouts only, through an explicit per-launch setting, never on the primary or secondmates, and after the Claude Code upgrade.
The captain upgraded to 2.1.328 the same day.
The small guard fixes (items A, B1, E of the report's section 5) already merged in `specs/009-code-mode-guard-fixes`.
This slice is items C, D and F.

## Overview

Claude Code's experimental Code Mode lets the model write JavaScript that calls the session's tools.
It is enabled by `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1` in an interactive session, and the scout measured a modest saving on read-heavy work.
Three facts from the lab shape this slice.

1. Setting the variable in the shell that runs `bin/fm-spawn.sh` reaches a worker only when that spawn happened to start the multiplexer server, and `config/launch-env-allowlist` strips it unless listed.
   The only deterministic route is an assignment that is part of the launch line itself.
2. The first Code Mode launch per Claude config directory shows a confirmation dialog whose cursor sits on "No, start without it".
   Firstmate's key plane cannot select "Yes", a decline is not remembered, and `fm-spawn` still reported `spawned` while the worker sat on it.
   Acceptance is stored as `codeModeCaveatsAcceptedV1` in the config directory's `.claude.json`.
3. Every existing live Claude test uses `-p`, which cannot run Code Mode, so nothing proves a real interactive Code Mode launch end to end.

## User Scenarios and Testing

### User Story 1 - A scout launches in Code Mode only when the home asks for it (Priority: P1)

**Acceptance Scenarios**:

1. **Given** no `config/claude-code-mode`, **When** any Claude task is launched, **Then** the launch line carries `-u CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` and no assignment, so a stray environment cannot enable it.
2. **Given** `config/claude-code-mode` holds `scouts` and the config store records acceptance, **When** a scout is launched on Claude, **Then** the launch line carries `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1` as an assignment inside the launch line.
3. **Given** `scouts`, **When** a ship worker or a secondmate is launched on Claude (a relaunch re-enters the same launch construction), **Then** the launch line carries the `-u` form and no assignment.
4. **Given** `scouts` and a `config/launch-env-allowlist` that does not list the variable, **When** a scout is launched, **Then** the launch still carries the assignment, because it lives inside the launch line and not in the caller's environment.
5. **Given** the caller's own environment holds `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1`, **When** a ship worker is launched, **Then** the worker process does not see it.
6. **Given** a value other than `off` or `scouts`, or an unreadable file, **When** any spawn runs, **Then** the spawn refuses before any endpoint, worktree, or record exists and names the accepted values.
7. **Given** `config/claude-permission-mode` is `auto`, **When** a scout is launched under `scouts`, **Then** Code Mode stays off and the spawn output says why, because the auto-mode classifier reads code once and does not see the calls it makes.
8. **Given** a non-Claude harness or a raw launch command, **When** it is launched, **Then** nothing changes.

### User Story 2 - A worker is never parked on the first-run dialog (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `scouts` and a Claude config store without `codeModeCaveatsAcceptedV1` set to true (absent store, absent key, or false), **When** a scout is launched, **Then** it launches in the `-u` form and the spawn output carries one line saying Code Mode was skipped because the dialog has not been accepted for that config directory, naming the directory and the one-time acceptance step.
2. **Given** the store records acceptance, **Then** no skip line is printed and the scout launches with the assignment.
3. **Given** a pinned worker account (`config/claude-account`), **Then** the check reads the pinned root's store, the one the worker will read.
4. **Given** the check runs, **Then** it only reads the store and never writes it, and never answers the dialog.

### User Story 3 - The secondmate and the supervision engine are explicitly off (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `scouts`, **When** a Claude secondmate is launched, **Then** its launch line carries the `-u` form.
2. **Given** the caller's environment holds the variable, **When** the supervision host starts its Claude print engine, **Then** the engine process does not see it.

### User Story 4 - A real interactive Code Mode scout launch is proven live (Priority: P2)

**Acceptance Scenarios**:

1. **Given** an opt-in, lab-only run with a throwaway Claude login, **When** a scout is spawned through `bin/fm-spawn.sh` with `scouts`, **Then** the worker's pane shows the Code Mode banner and its transcript records a `REPL` tool call.
2. **Given** the same lab, **When** a ship worker is spawned, **Then** the pane shows no Code Mode banner.
3. **Given** the lab's store has no acceptance, **When** a scout is spawned, **Then** it starts without Code Mode and the pane never shows the confirmation dialog.
4. **Given** no credentials or no opt-in, **Then** the test skips, and it never touches the captain's `~/.claude`.

### User Story 5 - Maintainers can find the knob (Priority: P2)

1. `docs/configuration.md` owns the knob's schema and refusals.
2. The Claude adapter reference's Code Mode section states what the spawn now does.
3. `bin/fm-spawn.sh`'s header documents the knob in the same style as `config/claude-permission-mode`.

## Requirements

- **FR-001**: `config/claude-code-mode` MUST accept exactly `off` (default when absent) and `scouts`; anything else or an unreadable file MUST refuse every spawn before any mutation, naming the accepted values.
- **FR-002**: A non-raw Claude launch of kind scout under `scouts`, with recorded acceptance and a bypass permission mode, MUST carry `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1` as an assignment in the launch line.
- **FR-003**: Every other non-raw Claude launch (ship, secondmate, relaunch, scout under `off`, skipped scout) MUST carry `-u CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` in the launch line's `env` prefix.
- **FR-004**: The assignment and the unset MUST survive `config/launch-env-allowlist`; a test MUST prove it.
- **FR-005**: The acceptance check MUST be read-only, MUST read the store the worker will read (pinned root, else `CLAUDE_CONFIG_DIR`, else `$HOME`), and MUST treat any unreadable or unparsable store as not accepted.
- **FR-006**: A skipped Code Mode launch MUST print exactly one explanatory line in the spawn output and MUST NOT fail the spawn.
- **FR-007**: Under `claude-permission-mode=auto`, scouts MUST stay off and the spawn output MUST say why.
- **FR-008**: The supervision engine MUST NOT inherit the variable.
- **FR-009**: The primary is never launched by Firstmate, so no code path sets the variable for it; the knob MUST NOT be inherited into secondmate homes.
- **FR-010**: Nothing MUST read or write the captain's `~/.claude` or set the variable in any settings file.
- **FR-011**: `tests/fm-claude-codemode-live-e2e.test.sh` MUST be opt-in and lab-only, use the cheapest supported model with bounded prompts, and refuse any config directory that is not a throwaway.
- **FR-012**: Docs per Story 5, each fact stated once at its owner and cross-referenced elsewhere, one sentence per line.

## Out of scope

Ship-worker enablement, any change to the cd guard or the hooks, scanning REPL code, resume handling, and non-Claude harnesses.
Follow-ups noted, not built: an `onFailure` audit for hooks other than the three tracked ones.

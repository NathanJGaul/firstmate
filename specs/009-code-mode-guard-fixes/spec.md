# Feature Specification: Code Mode Guard Fixes

**Feature Branch**: `fm/firstmate-code-mode-guard-fixes`

**Created**: 2026-11-19

**Status**: Approved by the brief

**Input**: The captain accepted the Code Mode scout's recommendations on 2026-11-19 (report section 8): keep Code Mode off for the primary and secondmates, pilot scouts only later, and fix the persistent-cd guard now in the small form.
This slice is items A, B option 1, and E of the report's section 5.
Items C and D (the launch knob and the first-run dialog pre-flight) wait for a Claude Code upgrade and are out of scope, as are enabling Code Mode anywhere and scanning REPL code.

## Overview

Claude Code's experimental Code Mode lets the model write JavaScript that runs shell commands.
Two findings from the scout's lab matter to firstmate's tracked Claude hooks.

1. A shell call written `` $`cmd`.cwd(dir) `` reaches PreToolUse as `cd '<dir>' && cmd`.
   The persistent-cd guard denies it, although the wrapper does not persist (verified), so the denial is a false positive.
   It hit the wake drain itself when the model wrote the natural `.cwd(<home>)` form.
2. A PreToolUse hook that cannot start or times out refuses the call under Code Mode (`the hook failed, so this call was not run`), where it ran the call before.
   The tracked guards are fail-open by design, and that design is silently inverted.
   Adding `"onFailure": "continue"` to a hook restores it (verified; the field exists since Claude 2.1.295).

The captain's installed Claude Code (2.1.316) silently ignores Code Mode, so nothing is at risk today.
This slice makes the tracked hooks and guard text right before anyone turns Code Mode on, and records the version floor and behavior facts where maintainers look for them.

## User Scenarios and Testing

### User Story 1 - A failing guard hook never refuses a call under Code Mode (Priority: P1)

**Acceptance Scenarios**:

1. **Given** the tracked `.claude/settings.json`, **When** it is parsed, **Then** it is valid JSON and every PreToolUse hook (three) is still a command hook carrying `"onFailure": "continue"`.
2. **Given** each tracked PreToolUse hook command, **When** its script is missing or not executable, **Then** the command fails with a launch-failure status (126 or 127) and writes nothing to stdout, never the deny status 2, so the hook failure is exactly the case `onFailure` governs and a deny is never mistaken for one.
3. **Given** a hook that genuinely denies (exit 2), **When** the guard denies, **Then** nothing changes: the deny channel is untouched.

### User Story 2 - The model is taught the Code Mode rule when the guard denies (Priority: P1)

**Acceptance Scenarios**:

1. **Given** the command a `.cwd()` call produces (`cd '<dir>' && bin/fm-wake-drain.sh`), **When** the guard denies it, **Then** the deny text says that under Code Mode `.cwd()` or a leading `cd` is a persistent-cd, never to pass either, and to use absolute paths or `git -C <dir>`.
2. **Given** any other denied command, **When** the guard denies, **Then** the same text is carried, still beginning with the stable `[persistent-cd]` code.
3. **Given** the full existing block and allow matrix, **When** it runs through every harness entry form, **Then** every verdict is unchanged: this slice changes what the guard says, not what it denies.

### User Story 3 - Maintainers can find the Code Mode facts (Priority: P2)

1. The Claude adapter reference records the version floor, the first-run confirmation dialog, hook failure semantics, the resume rule, and the cwd wrapper.
2. `docs/cd-guard.md` records the Code Mode rule and its residual false positive.
3. `docs/turnend-guard.md` records the hook failure semantics and `onFailure` for the PreToolUse seatbelts.
4. `docs/verification/supervision.md` records the dated lab evidence behind those facts.

## Requirements

- **FR-001**: The three tracked PreToolUse hooks MUST carry `"onFailure": "continue"` and keep their command, type, and matcher unchanged.
- **FR-002**: `.claude/settings.json` MUST stay valid JSON, and a test MUST fail if a PreToolUse hook lacks the field.
- **FR-003**: The `persistent-cd` deny text MUST carry the Code Mode rule (never `.cwd()` or a leading `cd`; absolute paths or `git -C`) and keep its code and its existing advice.
- **FR-004**: What the guard denies and allows MUST NOT change; no `repl_` exemption and no scan of REPL code.
- **FR-005**: The four documents in User Story 3 MUST carry the facts above, each fact stated once at its owner and cross-referenced elsewhere, with one sentence per line.
- **FR-006**: No launch knob, no spawn change, no change to enabling Code Mode, and no other hook edited.

## Edge Cases

- Other loaders of `.claude/settings.json` (Grok, Cursor, pi-code) see an extra field they may ignore; the sign-in-gated Grok could not be probed here, which the verification record states.
- Claude older than 2.1.295 does not know the field; the installed 2.1.316 does.
- The false positive remains for a `.cwd()` call whose model ignores the new text; the guard still denies it, and the text names the way out.

## Out of Scope

Items C, D, and F of the report; an exemption keyed on `repl_` ids; scanning REPL code; a live Code Mode end-to-end test; enabling Code Mode on any surface.

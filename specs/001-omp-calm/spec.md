# Feature Specification: OMP Calm presentation

**Feature Branch**: `fm/omp-firstmate-calm`

**Created**: 2026-10-06

**Status**: Approved for planning

**Input**: User description: "Extend the existing Firstmate Calm presentation feature to OMP (Oh My Pi). The existing feature is supported on Pi and Claude Code and shares the home-local config/calm preference; OMP needs the same feature rather than a separate preference or presentation contract."

## User Scenarios & Testing

### User Story 1 - Toggle shared Calm preference in OMP (Priority: P1)

An OMP user can turn Calm on or off with `/calm`, and the choice is the same home-local choice already used by Pi and Claude Code.

**Why this priority**: The toggle and shared persistence are the feature's entry point and must work before presentation changes can be trusted.

**Independent Test**: Start OMP with the preference absent, run `/calm`, restart with the same Firstmate home, and verify the choice remains active; toggle again and verify it returns to ordinary presentation.

**Acceptance Scenarios**:

1. **Given** OMP is running with no Calm preference, **When** the user runs `/calm`, **Then** OMP enables Calm, writes the shared preference, and reports the choice without adding a transcript row.
2. **Given** the shared preference is enabled, **When** OMP starts or resumes, **Then** Calm is active before transcript rows are rendered.
3. **Given** Calm is active, **When** the user runs `/calm` again, **Then** OMP disables Calm, writes the shared preference, and restores ordinary presentation.
4. **Given** the preference cannot be read or written, **When** the user runs `/calm`, **Then** OMP keeps the last known choice and reports the persistence problem without changing execution.

---

### User Story 2 - Keep OMP work and conversation readable (Priority: P1)

An OMP user with Calm enabled sees the same compact animated working presentation and supported transcript cleanup used by the existing Calm contract, while genuine prompts and answers remain visible.

**Why this priority**: Presentation is the user-visible value of Calm and must preserve the information needed to follow a run.

**Independent Test**: Exercise an OMP run with working activity, tool activity, operational input, working notes, genuine user text, and a final answer, then compare Calm-on and Calm-off rendering while inspecting the unchanged execution and stored transcript.

**Acceptance Scenarios**:

1. **Given** an OMP run is active and Calm is enabled, **When** working activity is displayed, **Then** OMP shows the animated Calm working ship at the available width and removes it when the run settles, aborts, or fails.
2. **Given** Calm is enabled, **When** the supported synthetic custom-message row or another OMP transcript class is rendered, **Then** the supported row occupies no transcript height while unsupported rows, genuine user prompts, substantive assistant text, and the final answer remain visible.
3. **Given** Calm is disabled, **When** the same run is rendered, **Then** OMP leaves its ordinary working and transcript presentation unchanged.
4. **Given** a hidden row is rendered while Calm is enabled, **When** execution completes or the session is exported, **Then** the original message, model context, tool execution, session data, and export remain complete and unchanged.

---

### User Story 3 - Continue safely across OMP API variation (Priority: P2)

An OMP user can use Calm when supported presentation seams are available, and an unavailable seam does not disable the rest of Calm or affect ordinary OMP execution.

**Why this priority**: OMP's extension API may expose some presentation controls without exposing a global renderer, so unsupported pieces must degrade independently rather than corrupting a session.

**Independent Test**: Start OMP with each supported presentation seam present and absent in isolation, then verify diagnostics identify only the unavailable seam while the toggle, preference, remaining adapters, and execution continue to work.

**Acceptance Scenarios**:

1. **Given** one supported OMP presentation seam is unavailable, **When** Calm loads, **Then** OMP emits a diagnostic naming that seam and keeps unrelated Calm behavior available.
2. **Given** OMP has no supported seam for a transcript class, **When** Calm is enabled, **Then** that class remains ordinary and no unsupported filtering or message mutation occurs.
3. **Given** Pi and Claude Code are installed alongside OMP, **When** OMP Calm changes are exercised, **Then** their existing Calm behavior and shared preference contract remain unchanged.

### Edge Cases

- OMP starts with an existing `config/calm` value of `on`, `off`, `max`, or an unrecognized value.
- OMP's working presentation is resized, hidden temporarily, or re-mounted during one logical run.
- A working-note text is exactly at the shared preservation threshold, contains a newline, or is empty.
- An operational-input envelope is a near miss or carries unsupported content, such as an image-bearing row.
- A supported OMP presentation method is missing, throws during installation, or is replaced by a later OMP release.
- Calm is toggled while rows from the current run are already on screen.

## Requirements

### Functional Requirements

- **FR-001**: OMP MUST expose `/calm` as an off-by-default presentation toggle.
- **FR-002**: OMP MUST read and write the existing effective-home `config/calm` preference and MUST NOT create a separate OMP preference.
- **FR-003**: OMP MUST apply the shared Calm visibility policy to each transcript class only where OMP exposes a supported presentation boundary.
- **FR-004**: OMP MUST preserve genuine user prompts, substantive assistant text, working activity, model context, execution, session storage, and exports.
- **FR-005**: OMP MUST render the harness-neutral Calm working ship while a logical run is active and remove it when that run settles, aborts, or fails.
- **FR-006**: OMP MUST preserve ordinary OMP rendering and execution when Calm is off.
- **FR-007**: OMP MUST diagnose and independently skip an unavailable presentation seam without disabling unrelated Calm behavior.
- **FR-008**: OMP MUST reuse the canonical operational-input classification and shared working-note preservation semantics rather than introducing a second contract.
- **FR-009**: OMP Calm behavior MUST be covered by focused executable behavior tests, and the Calm documentation and maintainer verification MUST identify the OMP support boundary and evidence.
- **FR-010**: Existing Pi and Claude Code Calm behavior MUST remain unchanged.

### Key Entities

- **Calm preference**: The home-local persisted choice, represented by the existing `config/calm` file and shared by supported harnesses.
- **Calm presentation state**: The in-process active/off state and supported adapter availability used to decide whether OMP draws ordinary or Calm presentation.
- **Working presentation**: The transient animated ship shown for active work without creating a transcript or session entry.
- **Transcript row class**: A supported OMP-rendered presentation category classified as genuine conversation, working activity, operational input, tool activity, or working note.

## Success Criteria

### Measurable Outcomes

- **SC-001**: OMP `/calm` toggling and preference restoration pass in focused tests for absent, enabled, disabled, legacy, and write-failure preference states.
- **SC-002**: Focused OMP presentation tests demonstrate that every supported hidden-row class contributes zero transcript height while genuine prompts and substantive responses remain visible.
- **SC-003**: Focused OMP working-presentation tests demonstrate deterministic animation, resize handling, and cleanup on settled, aborted, and failed runs.
- **SC-004**: Focused preservation tests demonstrate identical operational input, tool execution, stored transcript, model context, and export content with Calm on and off.
- **SC-005**: Compatibility tests demonstrate that removing each supported OMP seam produces a targeted diagnostic and leaves the toggle and unrelated adapters usable.
- **SC-006**: Existing Pi and Claude Code Calm regression suites remain green after the OMP change.

## Assumptions

- OMP provides a verified extension API for commands, lifecycle/session events, working presentation, and at least some transcript rendering controls, but it may not expose every renderer boundary required by the full Calm policy.
- OMP's effective Firstmate home can be resolved using the same environment and configuration semantics already implemented for Pi and Claude Code.
- OMP's own transcript and extension test utilities are available locally or can be exercised through the repository's existing behavior-test runner without adding dependencies.
- Maintainer verification records current OMP version and exact smoke commands separately from the user-facing Calm contract.
- Unavailable OMP presentation controls remain visible rather than being hidden through transcript mutation, provider-context filtering, or installed OMP code changes.

## Out of Scope

- Calm support for Codex, OpenCode, Grok, or any harness not named in this feature.
- Changes to the Pi or Claude Code presentation contracts except where a shared neutral helper must remain compatible.
- Changes to model prompts, provider context, tool execution, session serialization, export formats, or unrelated OMP features.

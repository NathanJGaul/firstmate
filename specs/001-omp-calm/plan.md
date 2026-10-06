# Implementation Plan: OMP Calm presentation

**Branch**: `fm/omp-firstmate-calm` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-omp-calm/spec.md`

## Summary

Add a native OMP extension under `.omp/extensions` that owns the `/calm` command, reads and writes the existing home-local preference, animates the shared Calm working ship through OMP's working-message API, and installs only supported transcript adapters. Reuse the harness-neutral Calm preference, sprite, and visibility policy instead of creating an OMP-specific preference or filtering contract. Unsupported OMP renderer seams remain visible and produce targeted diagnostics. Add focused portable behavior tests and current OMP maintainer evidence without changing Pi or Claude Code semantics.

## Technical Context

**Language/Version**: TypeScript loaded by OMP's Bun extension runtime; Bash behavior-test scripts

**Primary Dependencies**: OMP 18.6.1 extension API; existing Firstmate Calm TypeScript helpers; Node/Bun standard filesystem APIs; no new dependencies

**Storage**: Existing effective-home `config/calm` preference; no session or transcript storage changes

**Testing**: Existing `bin/fm-test-run.sh` with focused Bash test script and Node/Bun executable behavior probes; no separate OMP test runner is installed

**Target Platform**: OMP 18.6.1 on the supported Firstmate Linux/macOS/Windows hosts; portable tests run under Linux CI

**Project Type**: In-process terminal extension plus shell-based integration tests

**Performance Goals**: Calm timer updates must remain bounded to the shared 220 ms sprite cadence and stop when the logical run ends; no per-row subprocess or filesystem access

**Constraints**: OMP exposes `setWorkingMessage` but not `setWorkingVisible`, a generic transcript filter, or a native tool-row renderer; unsupported rows must remain ordinary; no model, context, session, export, or installed-binary mutation

**Scale/Scope**: One OMP extension, shared Calm policy/sprite helpers, one focused behavior test, two maintained prose surfaces, and one maintainer-verification record

## Research Summary

- OMP native discovery loads `.omp/extensions/*.ts` from the current project.
- `setWorkingMessage`, managed timers, and `registerMessageRenderer` are the supported seams used by this plan.
- OMP has no current generic user-row/transcript filter and no `setWorkingVisible`; those boundaries remain visible and are diagnosed.
- The shared sprite and pure presentation policy remain the single source of truth.

## Project Structure

### Documentation (this feature)

```text
specs/001-omp-calm/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
├── tasks.md
├── tdd/
│   ├── test-list.md
│   └── cycle-log.md
├── checklist.md
├── analyze.md
└── converge.md
```

### Source Code (repository root)

```text
.omp/extensions/
├── fm-calm.ts                         # OMP registration, lifecycle, command, adapters
└── lib/
    └── fm-calm-omp-presentation.ts    # OMP working-message projection and adapter glue

.claude/mods/firstmate-calm/lib/
├── fm-calm-presentation.ts             # harness-neutral preference and classification policy
├── fm-calm-visibility.ts               # policy compatibility export used by Pi
└── fm-calm-working-ship-sprite.ts       # shared geometry and animation state

tests/
└── fm-calm-omp-extension.test.sh       # OMP contract and executable behavior coverage

docs/
├── calm.md                             # user-facing OMP section and bounds
├── calm-mode-feasibility.md            # OMP evidence and API boundary
└── verification/runtime-backends.md    # dated OMP maintainer verification command/result
```

**Structure Decision**: Keep OMP-specific engine glue under `.omp/extensions`, keep reusable presentation decisions and sprite geometry in the existing Calm library, and colocate the behavior test with the current Calm Pi/Claude tests. The OMP extension must not import Pi-only component classes or change OMP's installed binary.

## Data Model

- `CalmPreference`: existing file value `on`, `off`, or legacy `max`; OMP reads and writes it exactly as the other supported harnesses do.
- `OmpCalmState`: factory-local active flag, current logical run flag, animation instance, managed timer handle, and installed-adapter flags; it is transient and never serialized.
- `OmpCalmAdapter`: independently installed seam with a stable name, install function, and diagnostic on unsupported or failed installation.

## Interface Contracts

- The default export from `.omp/extensions/fm-calm.ts` receives OMP `ExtensionAPI` and registers only through verified extension methods.
- `/calm` toggles the shared preference and invalidates mounted supported synthetic components so newly rendered or remounted rows use the new state. Persistence failures do not change the current active state.
- OMP lifecycle handlers use `session_start`, `agent_start`, `agent_end`, and `session_shutdown`; no handler injects model messages or changes session entries.
- The working adapter updates `ctx.ui.setWorkingMessage()` from the shared animation on the managed timer and restores the host default by passing `undefined` only after Calm has taken ownership and the run is off or terminal.

## Implementation Phases

### Phase 0: Shared policy and test seam

1. Add or re-export a harness-neutral transcript visibility policy without changing the existing Pi-visible behavior.
2. Add pure OMP presentation helpers that can be exercised without a live model, including preference failure handling, width-bounded sprite projection, and adapter diagnostics.
3. Add focused tests before each behavior implementation and record red/green evidence in the TDD cycle log.

### Phase 1: OMP extension

1. Implement shared preference resolution and atomic persistence in the OMP extension.
2. Register `/calm` and session lifecycle handlers.
3. Install the managed animated working-message adapter.
4. Install the legacy custom-message renderer; leave OMP transcript classes without a supported renderer ordinary and diagnose that boundary.
5. Emit one diagnostic per unsupported or failed seam and preserve all ordinary behavior.

### Phase 2: Documentation and verification

1. Add the OMP user-facing contract and explicit unsupported boundaries to `docs/calm.md`.
2. Add dated OMP API/version evidence and focused regression commands to `docs/calm-mode-feasibility.md`.
3. Update `docs/verification/runtime-backends.md` only with the exact OMP command and observed result.
4. Run documentation audience checks and the relevant behavior suites.

## Risk Controls

- OMP-specific state is factory-local so child sessions and reloads do not share active presentation state.
- Timers use OMP's managed timer API, retain handles until `clearTimer` succeeds, and are stopped on every terminal lifecycle path.
- OMP does not claim native tools or unsupported transcript classes, so their execution and ordinary rendering remain host-owned.
- Missing UI or renderer methods are caught per adapter and surfaced with the adapter name.
- No unsupported transcript filtering, input interception, context mutation, persistence rewrite, or installed OMP patching is allowed.

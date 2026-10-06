# OMP Calm presentation checklist

**Purpose**: Requirements-quality gate for the completed OMP Calm feature.
**Review basis**: `spec.md`, `plan.md`, `tasks.md`, `contracts/omp-extension.md`.

## Completeness

- [x] Shared `config/calm` preference, `/calm`, session restoration, and write-failure behavior are specified.
- [x] Working presentation, supported transcript seams, preservation guarantees, and unsupported OMP boundaries are specified.
- [x] Pi and Claude Code non-regression scope is explicit.

## Clarity and measurability

- [x] Preference values, persistence output, animation cadence, width bounds, and lifecycle cleanup are objectively testable.
- [x] Supported and unsupported OMP API seams are named rather than described as generic rendering behavior.
- [x] Diagnostics and ordinary fallback behavior are specified for missing or throwing seams.

## Scenario coverage

- [x] Primary toggle and working-run scenarios are covered.
- [x] Recovery and failure scenarios include write failures, missing APIs, foreign tool ownership, settle, abort, shutdown, and unsupported rows.
- [x] Preservation scenarios cover execution parameters/results and document the unavailable OMP export runner.

## Review note

The requirements-quality checklist is complete. Implementation and TDD evidence are recorded separately in `tdd/verification.md`; the observed Pi regression limitation remains a validation finding, not a silently accepted requirement change.

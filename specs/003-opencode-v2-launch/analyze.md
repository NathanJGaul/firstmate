# Analysis: OpenCode v2 Worker Launch

Implementation matches `spec.md`, `plan.md`, and `tasks.md`.

- FR-001: template is `opencode --auto --prompt "$(<encode> < brief)"`; the encoder is `bin/fm-operational-input.sh` and still works on 2.2.5.
- FR-002: pin written, excluded, and a tracked file refused; one deliberate behavior beyond the spec text: with no model, an untracked stale pin is removed.
- FR-003: effort recorded in meta, omitted from launch.
- FR-004: dual-entry default export, covered for 2.x and 1.x.
- FR-005: only opencode branches changed.
- FR-006: reference and configuration doc updated.

Findings: none blocking.
Observation for follow-up, out of scope: the primary-side `.opencode/plugins/fm-primary-*.js` use the 1.x named-export form and fail to load on 2.2.5, so a primary on OpenCode 2.x runs without its turn-end guard, watch-arm, and session-start plugins.

# Analysis: Code Mode Guard Fixes

Spec, plan, tasks, and tests agree.

- FR-001, FR-002: `.claude/settings.json`; A1, A2.
- FR-003: the `persistent-cd` reason in `bin/fm-cd-command-policy.mjs`; A3.
- FR-004: no decision logic edited; A4.
- FR-005: the four documents; the doc audit.
- FR-006: only the listed files changed.

Compatibility review: Claude is the only reader of `onFailure`; Codex, OpenCode, Pi, and omp use separate registrations and are untouched; Grok, Cursor, and pi-code load the same file and are unverified for the extra field (stated in the verification record).
No other hook field or registration moved, so the existing Grok marker guard test (`tests/fm-turnend-guard.test.sh`) still passes unchanged.

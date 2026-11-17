# Quality Checklist: Per-Worker Browser Session

**Created**: 2026-11-17
**Feature**: [spec.md](spec.md)

## Requirements traceability

- [x] FR-001 every local launch exports the task id: A1 to A6
- [x] FR-002 the export overrides a pane value: A4, A7, A8
- [x] FR-003 the export survives the allowlist and a missing pane export: A7, A8
- [x] FR-004 ids that cannot name a session get no export: A14, U4 to U9
- [x] FR-005 cleanup stops the task's own session with the session set explicitly: A9, A16
- [x] FR-006 the stop follows the reap and passes every refusal: A10, A13
- [x] FR-007 the stop is best effort: A11, A12, U11
- [x] FR-008 the stop is bounded: U10
- [x] FR-009 never the default session or another session: A15, A16, A17
- [x] FR-010 one owner for the rule: `fm_browser_session_name`, used by both scripts
- [x] FR-011 documentation states the contract: `docs/configuration.md`, spawn and teardown headers

## Repository quality gates

- [x] One sentence per line in new Markdown, plain dashes, no agent co-author in commit messages
- [x] `bin/*.sh` pass the repository lint
- [x] Tests colocated in existing files and run by the existing runner
- [x] No new `bin/` library, no change to the allowlist format
- [x] The new environment knob `FM_TEARDOWN_BROWSER_STOP_TIMEOUT` is documented beside its sibling
- [x] Residual risks (port-hash collision, operator-set port, shared task id across homes) recorded in the specification

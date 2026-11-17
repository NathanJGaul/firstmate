---
feature: 004-worker-browser-session
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 18
planned_at: af20b2c9
updated_at: af20b2c9
suite_baseline: unknown
---

# Test List: Per-Worker Browser Session

Trace ids: `US<n>.<m>` is acceptance scenario `<m>` of user story `<n>` in `spec.md`, and `FR-<n>` is a functional requirement.

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`.
Each is observed through the real entry point: the spawn script and its emitted launch command run in a synthetic pane, or the teardown script run against a sandbox home with a fake `chrome-devtools-axi` first on `PATH`.

| id  | behavior                                                                                                                | traces              | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------------- | ------------------- | ------- | ------- | ---- |
| A1  | A ship worker launched with no allowlist starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its task id                  | US1.1, US2.3, FR-001 | example | PENDING |      |
| A2  | A scout worker starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its task id                                           | US1.2, FR-001       | example | PENDING |      |
| A3  | A local secondmate starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its own id                                        | US1.3, FR-001       | example | PENDING |      |
| A4  | A pane already carrying another `CHROME_DEVTOOLS_AXI_SESSION` still yields the task id                                  | US1.4, FR-002       | example | PENDING |      |
| A5  | A relaunch through `fm-control.sh relaunch` yields the same task-id session for the replacement agent                   | US1.5, FR-001       | example | PENDING |      |
| A6  | Two workers with different task ids start with different sessions                                                       | US1.6, FR-001       | example | PENDING |      |
| A7  | Under a present, empty allowlist the cleared-environment launch still yields the task-id session                        | US2.1, FR-003       | example | PENDING |      |
| A8  | Replaying only the launch command, without the pane-side exports, yields the task id in both allowlist postures         | US2.2, FR-003       | example | PENDING |      |
| A9  | Cleanup of a task whose launch exported a session runs `chrome-devtools-axi stop` once with that session                | US3.1, FR-005       | example | PENDING |      |
| A10 | The stop happens after the leaked-process cleanup for the task                                                          | US3.2, FR-006       | example | PENDING |      |
| A11 | A stop that exits non-zero, or that exceeds its bound, leaves cleanup complete with an unchanged exit status and a warning | US3.3, FR-007, FR-008 | example | PENDING |      |
| A12 | With no `chrome-devtools-axi` on `PATH`, cleanup completes with no warning and no error                                 | US3.4, FR-007       | example | PENDING |      |
| A13 | A cleanup that refuses because work is unlanded issues no stop                                                          | US3.5, FR-006       | example | PENDING |      |
| A14 | A spawn for a task whose id is `default` exports no `CHROME_DEVTOOLS_AXI_SESSION` of its own                            | US4.1, FR-004       | example | PENDING |      |
| A15 | Cleanup of a task whose id is `default` issues no stop                                                                  | US4.2, FR-009       | example | PENDING |      |
| A16 | Cleanup run by a caller whose environment names another session still stops the task's id                                | US4.3, FR-005, FR-009 | example | PENDING |      |
| A17 | Cleanup of a legacy path-safe id longer than 64 characters issues no stop                                               | US4.4, FR-004, FR-009 | example | PENDING |      |

## Inner loop: unit behaviors

### `bin/fm-pr-lib.sh` (`fm_browser_session_name`)

| id  | behavior                                                                  | traces        | kind    | state   | test |
| --- | ------------------------------------------------------------------------- | ------------- | ------- | ------- | ---- |
| U1  | Prints a creation-valid id unchanged and returns 0                        | FR-001, FR-010 | example | PENDING |      |
| U2  | Accepts dots, underscores, and hyphens inside an id                       | FR-010        | example | PENDING |      |
| U3  | Accepts an id of exactly 64 characters                                    | FR-010        | example | PENDING |      |
| U4  | Refuses an id of 65 characters with status 1 and no output                | FR-004, FR-010 | example | PENDING |      |
| U5  | Refuses exactly `default` with status 1 and no output                     | FR-004, FR-009 | example | PENDING |      |
| U6  | Accepts ids that merely contain or extend `default`, such as `default-2`  | FR-004        | example | PENDING |      |
| U7  | Refuses an empty id                                                       | FR-004        | example | PENDING |      |
| U8  | Refuses an id with a leading dot                                          | FR-004        | example | PENDING |      |
| U9  | Refuses an id containing a space or other character outside `[A-Za-z0-9._-]` | FR-004     | example | PENDING |      |

### `bin/fm-teardown.sh` (stop bound)

| id  | behavior                                                                                              | traces        | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | ---- |
| U10 | A stop that hangs is ended at the configured bound and cleanup proceeds                               | FR-008        | example | PENDING |      |
| U11 | A non-numeric bound value falls back to the default instead of aborting cleanup                       | FR-007, FR-008 | example | PENDING |      |

## Invariants and edge cases still to place

- The launch for a relaunch keeps the same session name as the original launch (covered by A5).
- Cleanup of a task spawned before this change stops a session that does not exist and is a no-op (not testable without the real tool; recorded in the specification's edge cases).

## Out of scope

- Remote secondmates: they never pass through the local launch path, and their coverage stays in `tests/fm-spawn-compact-adviser-disable-remote.test.sh`.
- Port collisions between session names, an operator-set `CHROME_DEVTOOLS_AXI_PORT`, and two homes sharing a task id: documented as residual risks in the specification and not testable without the real tool.
- Recycling existing default bridges: not part of this feature.
- A live check with the real `chrome-devtools-axi`: the tool is not a harness whose rendered output is parsed, so the fake proves Firstmate's side; the real tool's `stop` semantics are recorded in `research.md` from its source.

## Verification commands

Copied from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `bin/fm-test-run.sh {file}`
- Full suite: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`
- Coverage (runner inventory guard): `bin/fm-test-run.sh --check-coverage`
- Mutation: none installed; high-risk behavior is checked with deliberate mutants recorded in `tdd/verification.md`

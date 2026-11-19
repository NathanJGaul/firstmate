# Analysis: Orca Endpoint Presence

Spec, plan, tasks, and tests agree.

- FR-001 to FR-004: `fm_backend_orca_endpoint_state`; U1 to U5, A13.
- FR-005: `fm_backend_target_exists`; A1, A2.
- FR-006: `fm_backend_orca_agent_state` and the Orca arm of `fm_backend_agent_state`; A5, U6.
- FR-007: `pane_readable` and the no-run fallback in `bin/fm-crew-state.sh`; A3, A4.
- FR-008: the digest needed no code change; A2.
- FR-009, FR-010: no edit to the capability table or any other backend; A6.
- FR-011: lab step A13 and the dated record in `docs/verification/runtime-backends.md`.

Deviation from the plan text: D3 said crew state would call `fm_backend_target_exists`; it calls the adapter's endpoint read directly and keeps the verdict, because going through `fm_backend_agent_state` as well made two reads that could disagree.
The plan's Project Structure listed `tests/fm-crew-state.test.sh`; the crew-state cases live in `tests/fm-backend-orca.test.sh`, which already drives `fm-crew-state.sh` against the fake `orca`, and `tests/fm-crew-state.test.sh` was re-run unchanged as a regression.

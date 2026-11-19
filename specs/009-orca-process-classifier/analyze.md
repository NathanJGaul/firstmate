# Analysis: Orca Local Process Classifier

Spec, plan, tasks, and tests agree.

- FR-001, FR-002, FR-007, FR-009: `fm_backend_orca_process_scan`, `fm_backend_orca_process_state_sample`; U1 to U7, A1 to A4.
- FR-003: the endpoint-first `fm_backend_orca_agent_state`; A9.
- FR-004: the verdict mapping and `fm_backend_orca_process_state`'s settle; A1 to A5, U8.
- FR-005: `fm_backend_orca_runtime_is_local` and the `none`/`unsupported` mappings; A6, A7.
- FR-006: the unreadable tally and the opaque-environment rule; A8, U5, U10.
- FR-008: no `orca` call beyond the presence read; the one-call test.
- FR-010, FR-011: no edit to the capability table or any other backend; A10.
- FR-012: lab step A14 and the dated record in `docs/verification/runtime-backends.md`.

Deviations from the first plan text:

- D1 first said an environment that cannot be read counts toward `unreadable`; the first live run showed that makes `dead` unreachable on a desktop, so a refused read (`EACCES`, `EPERM`) is opaque and only other failures tally.
  The parent links now come from every process's `stat`, so a descendant below a helper of another user is still found; spec, plan, and research were updated to match.
- The Firstmate-level lab section's stand-in harness changed from `sh -c cat` to a real binary named `claude`, because `fm-control interrupt` refuses an endpoint that reads `ambiguous`.
- The plan listed only `tests/fm-backend-orca.test.sh` and the lab; the lab's step A13 expectation for a live terminal changed from `unverified` to `dead`.

# Analysis: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

Spec, plan, tasks, and tests agree.

- FR-001: `fm_control_backend_state_verified` and `fm_control_backend_supports_close_terminal`; U1.
- FR-002: the Orca arm of `do_exit` and `close_terminal_gate`; A1-A3.
- FR-003, FR-004: `--close-terminal`, `do_close_terminal`, `fm_backend_orca_close_terminal`; A6, A8, U2, lab step A15.
- FR-005: `fm_backend_orca_absence_verdict` through `fm_control_endpoint_absence_verdict`; U3, A2, A3.
- FR-006, FR-007: the Orca identity and rebind arm of `bin/fm-spawn.sh --relaunch`, `fm_backend_orca_reclaim_terminal`; A4, A5, U4.
- FR-008, FR-009: `ORCA_RELAUNCH_NEW_TERMINAL` and its abort cleanup, kept apart from `ORCA_ABORT_CLEANUP`; A9 and the `worktree` assertions.
- FR-010, FR-011: the runtime check and the secondmate refusal in the relaunch gate; U6, the secondmate case.
- FR-012: the interrupt proof in `verify_interrupt_running`; U5 and the three existing interrupt tests.
- FR-013: `docs/agent-control.md`, `docs/orca-backend.md`, the skill line, the script headers, and the dated record.

Deviations from the first plan text:

- The plan did not predict that the real runtime answers `ptyKilled: true` for a repeat close; the lab showed it, so the close receipt is documented as necessary and never sufficient, and the confirmation wait carries the proof.
- The relaunch preflight (`close_terminal_gate` before the transaction starts) was added so an `alive` Orca agent without the flag is refused before the instructions are touched; the rollback still restores them byte-exact for every later refusal.
- `tests/fm-spawn-orca-worktree.test.sh` asserted the old refusal; it was rewritten to pin the relaunch carve-out the refusal used to guard.
- The lab drives `fm-spawn --relaunch --harness <raw>` rather than `fm-control relaunch`, because the control verb accepts only verified harness names and the lab runtime's `PATH` may not hold an executable named for a real agent.

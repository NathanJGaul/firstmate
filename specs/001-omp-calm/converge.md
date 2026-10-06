# Convergence Report: OMP Calm presentation

**Inputs**: `spec.md`, `plan.md`, `tasks.md`, `checklist.md`, `analyze.md`, and `tdd/verification.md`.
**Outcome**: implementation scope converged; validation findings remain explicit.

## Requirements and plan

- All functional requirements FR-001 through FR-010 have an implementation or regression task.
- All tasks T001 through T025 are marked complete.
- The implementation uses the shared Calm preference, supported visibility policy, and working-sprite core; unsupported operational and assistant rows remain host-owned, and it does not add an OMP-specific preference or mutate context, execution, sessions, exports, or the installed OMP binary.
- Unsupported OMP generic transcript rows remain ordinary and are diagnosed rather than filtered through an undocumented seam.

## Evidence

- OMP focused behavior suite: pass, 14 checks, 0 failures; existing mounted synthetic rows remain unchanged until host remount as documented.
- Claude shared Calm regression suite: pass, 5 checks, 0 failures.
- OMP 18.6.1 inactive and active startup smokes: pass; deliberate generic-row diagnostic observed.
- Documentation audience check: pass (`102` surfaces, `454` local links).

## Open validation findings

1. The Pi suite has an observed `rendered export DOM violated the Calm conversation boundary` failure plus missing installed Pi package evidence. This is recorded in `tdd/verification.md` and remains a blocker for claiming FR-010/SC-006 fully green.
2. TDD history does not contain feature commits, so later test-after corrections cannot be represented as proven per-cycle red-green ordering.
3. No OMP interactive export acceptance runner or mutation tool is available in the recorded stack profile.

No additional implementation task was appended: these findings require environment/baseline or validation follow-up, not an inferred OMP feature expansion. The feature is ready for the selected delivery pipeline only with the Pi limitation carried forward.

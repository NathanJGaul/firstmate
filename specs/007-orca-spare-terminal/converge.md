# Convergence: Orca Spare Terminal

## Verdict

The feature meets its specification and is ready for delivery through the selected pipeline.
No unbuilt work remains.

## Evidence

- Fake-Orca suite `tests/fm-backend-orca.test.sh`: green (U1-U7, A1-A8 and every existing case).
- `tests/fm-spawn-orca-worktree.test.sh`, `tests/fm-backend-orca-lab-guard.test.sh`, `tests/fm-teardown-endpoint-safety.test.sh`, `tests/fm-backend.test.sh`: green, see the list in the delivery report.
- Live lab, isolated runtime, Orca 1.4.261 Linux headless: `passed=36 findings=3`, with `liveTerminalCount=1` after spawn and zero leftovers after teardown; the same live assertion was red against the previous adapter.
- `bin/fm-lint.sh`: clean.

## Risk

- Low: the change adds one read-only `terminal list` call in the single case that previously always created a spare terminal, and every failure of that read degrades to the previous behavior.
- A runtime that creates its terminal after the response returns would still get one created terminal, as before.
- The listing relies on Orca scoping `--worktree` correctly; the adapter additionally refuses any row naming another worktree.

## Remaining work

None for this feature.
Other evaluation-plan slices (capability gate, Escape delivery, agent state, receipts) are out of scope.

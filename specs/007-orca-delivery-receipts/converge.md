# Convergence: Orca Delivery Receipts

Merge readiness: ready for the delivery pipeline.

- Built: capability-gated receipt path in `bin/backends/orca.sh` with the unchanged literal loop as fallback; `terminal-gone` verdict with nonzero exit; ring maps it to 3; docs and the live record updated.
- Evidence: the three touched suites, lint, the doc audit, 12 mutants, and the live lab (`passed=43 findings=6`).
- Risk: low. The receipt path only runs on a runtime listing the capability. A terminal momentarily not writable would cost one early escalation, not lost work.
- Remaining: a real `turn_started` receipt is unobserved live (no agent in the lab starts a turn). Agent-state proof and Escape delivery stay with their own slices; the capability helper is the one place to unify with the Escape slice's capability record on rebase.

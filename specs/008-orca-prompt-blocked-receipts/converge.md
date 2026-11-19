# Convergence: Orca Prompt-Blocked Receipts

Merge readiness: ready for the delivery pipeline.

- Built: the `blocked` receipt class, the `prompt-blocked` verdict, the ring mapping to a failed ring, the hook-less fixture, docs, and the live lab step.
- Evidence: the three touched suites, lint, the doc audit, seven mutants, and the lab (`passed=30 findings=4`, unrelated findings).
- Risk: low. Only a runtime that lists the receipt capability and refuses a send reaches the new path; a refusal types nothing.
- Remaining: a real Claude harness's trust dialog is unobserved. The Escape-delivery and spare-terminal PRs touch nearby code; expect ordinary rebase work in `bin/backends/orca.sh`.

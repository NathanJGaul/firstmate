# Convergence: OpenCode v2 Worker Launch

Status: ready for delivery.

Evidence: spawn launch and pin tests, busy-state plugin tests for 2.x and 1.x, two killed mutants, adjacent suites (`fm-busy-state`, `fm-control`, `fm-harness-precedence`, `fm-dispatch-resolve`), pinned lint, documentation audit, and a live 2.2.5 TUI check.

Risk: low and confined to the opencode launch path; a project that tracks its own `.opencode/opencode.json` now stops the spawn when a model is pinned.

Remaining work: none for this feature.

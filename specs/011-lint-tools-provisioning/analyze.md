# Analysis: Pinned Lint Tools Visible to the No-Mistakes Pipeline

Spec, plan, tasks, and tests agree.

- FR-001, FR-003: `fm_lint_tool_resolve` in `bin/fm-lint-tools-lib.sh` and its use in `bin/fm-lint.sh` and `bin/fm-lint-workflows.sh`; A1-A3, U4.
- FR-002, FR-004: `fm_lint_tools_dir`; U1-U3.
- FR-005: the optional destination of `bin/fm-install-shellcheck.sh` and `bin/fm-install-actionlint.sh`; U5, U6.
- FR-006: `bin/fm-install-lint-tools.sh`; A4-A7, U7, U8.
- FR-007: the two missing-tool messages; A8.
- FR-008: no daemon call anywhere in the change; U9.
- FR-009: `CONTRIBUTING.md` and `docs/configuration.md`.

Deviations from the first plan text:

- The plan did not predict that the suites copy the lint entry points into temporary trees; each copy now also copies the library.
- A pre-existing failure was found: `tests/fm-lint.test.sh` required a per-root RSS reading that the production code correctly reports as unavailable without `/usr/bin/time`; the assertion now applies only where that binary exists (U12).
- The first form of the daemon-like search path in the new suite made one link per system executable per case and was slow under load; it is built once per run.

Operator step, not part of this change: the managed directory is empty until `bin/fm-install-lint-tools.sh` runs once on the machine that hosts the daemon.

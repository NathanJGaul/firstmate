# Convergence: Per-Worker Browser Session

## Merge readiness

Ready for the no-mistakes pipeline and PR.
No tasks remain open on `tasks.md`, and every behavior on `tdd/test-list.md` is `DONE`.

## What was built

- `fm_browser_session_name` in `bin/fm-pr-lib.sh`: the one rule for which task ids name a browser session.
- A launch export of `CHROME_DEVTOOLS_AXI_SESSION=<task id>` in `bin/fm-spawn.sh`, beside the `FM_TASK_INBOX` export.
- A bounded, best-effort `chrome-devtools-axi stop` of the task's own session in `bin/fm-teardown.sh`, after the leaked-process reap.
- Documentation in `docs/configuration.md` and in both script headers.
- 28 new behavior tests in the two existing test files.

## Evidence

| Check | Result |
| --- | --- |
| `bin/fm-test-run.sh tests/fm-spawn-compact-adviser-disable.test.sh` | 25 ok, exit 0 |
| `bin/fm-test-run.sh tests/fm-teardown.test.sh` | 123 ok (113 at baseline plus 10 new), exit 0, about 20 minutes |
| `bin/fm-lint.sh` (changed-file mode) | exit 0 |
| `bin/fm-lint.sh` with full analysis on the two test files and `bin/fm-pr-lib.sh` | exit 0 |
| `LC_ALL=C bin/fm-test-run.sh --check-coverage` | ok |
| `bin/fm-doc-audience-check.sh` | see the PR run; the new spec files are classified |
| Deliberate mutants (helper, launch export, cleanup stop) | every mutant killed, every restored run passed |

## Remaining risk and follow-up

- `bin/fm-test-run.sh --check-coverage` fails under a non-C locale because of a `comm` sort-order assumption that this change does not touch; it passes under `LC_ALL=C`.
- The teardown test file grew by about 90 seconds; the serial lane budget check still passes.
- Residual risks recorded in the specification: port-hash collisions between session names, an operator-set `CHROME_DEVTOOLS_AXI_PORT`, and two homes sharing a task id.
- Full-analysis lint of the very large `bin/fm-spawn.sh` and `bin/fm-teardown.sh` did not finish locally in reasonable time; changed-file lint passed and CI runs the full pass.
- The captain's TDD constitution wording is still unratified; the feature followed the repository skill's TDD principle instead.

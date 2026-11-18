# TDD Verification: Orca Adapter Hygiene

Verdict: PASS, with the limits listed at the end.

## Test-first evidence

- `tdd/cycle-log.md` records, per cycle, the first failing assertion of each new test observed against the unchanged code, then the smallest change that turned it green.
- Git history does not show the order, because the three cycles are one implementation commit; the cycle log is the evidence.
- Characterization-only tests (U4 and the Darwin half of A5) passed on first run by design; they pin behavior that must not change.

## Suites run on the final tree

- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` - exit 0
- `bin/fm-test-run.sh tests/fm-bootstrap.test.sh` - exit 0 (it was red at the planning commit on this host from a pre-existing herdr hermeticity defect, fixed here)
- `bin/fm-test-run.sh tests/fm-backend.test.sh`, `tests/fm-spawn-orca-worktree.test.sh`, `tests/fm-bootstrap-network-parallel.test.sh` - exit 0 on the tree before the lint-only test edits, which touched only quoting and `shellcheck` directives
- `LC_ALL=C bin/fm-test-run.sh --check-coverage` - `FM_TEST_COVERAGE ok total=252`; without `LC_ALL=C` it prints `comm: file 2 is not in sorted order` on this host's locale, also at the planning commit, so that is a host locale issue and not this change
- `bin/fm-lint.sh` with ShellCheck 0.11.0 and actionlint 1.7.12 - exit 0
- `bin/fm-doc-audience-check.sh` - run after the files were committed, see the delivery notes
- The full profile suite was not run here; CI owns it.

## Test strength

No mutation tool is installed, so deliberate mutants were used.

- Removing the `fm_backend_orca_tool_check` call from `fm_backend_orca_worktree_create`: the off-PATH worktree test fails with `orca: command not found`.
- Each behavior is asserted on observable output (exit code, message text, the fake Orca's call log, task metadata), never on source text.
- The folder refusal tests assert both the message and the absence of every mutating Orca verb, so a refusal that still created anything would fail.

## Acceptance coverage

Every acceptance scenario in `spec.md` maps to a passing test, see `tdd/test-list.md` and `analyze.md`.

## Limits

- No live Orca was touched; behavior against a real folder-registered repository and the real `repo show` shape are open (lab slice).
- Mutation testing beyond the one targeted mutant above was not run.

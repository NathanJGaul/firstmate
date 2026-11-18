# Quality Checklist: Orca Fleet Plumbing

A checked box is a gate verified against the repository with the evidence beside it.
It is not a reviewer's approval of the requirements, and an unchecked box is explained.

- [X] Every acceptance scenario and edge case has a test, with no `NO_TEST` behavior (`tdd/test-list.md`, `tdd/verification.md`).
- [X] Every behavior that changed was written test-first: `tdd/cycle-log.md` cycles 1 to 3 each record a red before the change, and one commit per cycle holds the tests, the implementation, and the log entry.
- [X] No existing test was weakened, skipped, or excluded; the one existing assertion edited (`tests/fm-bootstrap.test.sh`, the herdr missing-CLI case) was made hermetic against a host-installed `herdr`, in its own commit, and its expectation is unchanged.
- [X] The diff is confined to `bin/fm-backend.sh`, `bin/fm-bootstrap.sh`, `bin/fm-spawn.sh`, `bin/fm-classify-lib.sh`, `bin/fm-watch.sh`, `bin/fm-push-transition-lib.sh`, their three test files plus `tests/fm-daemon.test.sh`, `docs/configuration.md`, `docs/documentation-audiences.json`, and `specs/005-orca-fleet-plumbing/`.
- [X] Bootstrap output, launch text with no allowlist, and tmux wake reasons are unchanged when no mixed fleet, no Orca, and no opaque handle is involved (A5, A11, U4, and the unchanged full suites).
- [X] The wake queue's routing key stays the recorded handle (A12, A13), and the daemon resolves the label form to the same task and markers (A14).
- [X] `bin/fm-lint.sh` is clean under the pinned ShellCheck 0.11.0 and actionlint 1.7.12.
- [X] `bin/fm-doc-audience-check.sh` is ok, with the feature records classified in `docs/documentation-audiences.json`.
- [X] `docs/configuration.md` states the union, the `tmux` default for an unrecorded backend, and the retained Orca variables.
- [X] The full touched suites pass on the final code: bootstrap, spawn-orca-worktree, watch-triage, daemon, and task-inbox (`tdd/cycle-log.md`).
- [ ] Live proof against a real Orca runtime (a mixed Orca and Herdr home at session start, an allowlisted Orca launch in a real terminal, an Orca wake in a real fleet): not possible, no Linux Orca lab exists; all proof uses fake `orca` fixtures, as the task requires.

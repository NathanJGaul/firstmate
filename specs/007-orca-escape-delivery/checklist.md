# Quality Checklist: Orca Escape and Ctrl+U Delivery

A checked box is a gate verified against the repository with the evidence beside it.
It is not a reviewer's approval of the requirements, and an unchecked box is explained.

- [X] Every acceptance scenario and edge case has a test, with no `NO_TEST` behavior (`tdd/test-list.md`, `tdd/verification.md`).
- [X] Every behavior that changed was written test-first: the tests are commit `59028a30` and the implementation follows it, with each red recorded in `tdd/cycle-log.md`.
- [X] No existing test was weakened, skipped, or excluded; the three assertions that said Orca could not deliver Escape or Ctrl+U were inverted or replaced by stronger ones, as the task asked.
- [X] Enter and Ctrl+C on Orca, and every other backend's keys, are unchanged (U7, A3, the unchanged `tests/fm-backend.test.sh`).
- [X] `exit` and `relaunch` still refuse on Orca (A6, and live in the lab).
- [X] `bin/fm-lint.sh` is clean under the pinned ShellCheck 0.11.0 and actionlint 1.7.12.
- [X] `bin/fm-doc-audience-check.sh` is ok, with the feature records classified in `docs/documentation-audiences.json`.
- [X] The Orca documentation, the control documentation, the recovery wording, and the key-support comments agree (grep for `does not deliver Escape` and `refuse today` finds only the exit and relaunch statements).
- [X] The suites that touch the changed files pass on the final code: orca, control, backend, spawn-orca-worktree, lab-guard, documentation-audiences, and the runner's own test.
- [X] Live proof against a real Orca runtime: the lab ran against its own runtime at 1.4.261 and passed.
- [ ] An interrupt of a real harness turn on Orca: not run. The lab's isolated home has no harness credentials, a turn spends model tokens, and a lab that borrowed the operator's credentials would breach its isolation.

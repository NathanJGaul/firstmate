# Quality Checklist: Orca Backend Leak Fixes

A checked box is a gate verified against the repository with the evidence beside it.
It is not a reviewer's approval of the requirements, and an unchecked box is explained.

- [X] Every acceptance scenario and edge case has a test, with no `NO_TEST` behavior (`tdd/test-list.md`: 26 behaviors, `tdd/verification.md` traceability).
- [X] Every behavior that changed was written test-first: `tdd/cycle-log.md` cycles 1 to 11 each record a red before the change, one commit per cycle holds the test, the adapter change, and the log entry, and `tdd/verification.md` passes (23 `PROVEN`, 3 pre-existing).
- [X] No existing test was weakened, skipped, or excluded; ten assertions only gained `--delete-branch` in their expected release argument list (`tdd/verification.md`).
- [X] The diff is confined to `bin/backends/orca.sh`, `tests/fm-backend-orca.test.sh`, `docs/orca-backend.md`, `docs/verification/runtime-backends.md`, `docs/documentation-audiences.json`, and `specs/004-orca-leak-fixes/`; `bin/fm-spawn.sh` and `bin/fm-teardown.sh` are untouched.
- [X] Teardown's landed-work refusals and id and path checks are unchanged: the four refusal tests that assert no worktree release pass, and `tests/fm-teardown-endpoint-safety.test.sh` passes (27 ok, 0 not ok).
- [X] The release never forces branch deletion and the change deletes no branch anywhere: the argument list is pinned exactly, and the branch diff adds no `git branch -d`, `-D`, or ref deletion (FR-007, FR-009).
- [X] `bin/fm-lint.sh` is clean under the pinned ShellCheck 0.11.0 and actionlint 1.7.12, and the changed shell files are clean under the CI settings (`shellcheck --norc --external-sources`).
- [X] `bin/fm-doc-audience-check.sh` is ok, with the feature records classified in `docs/documentation-audiences.json`.
- [X] `docs/orca-backend.md` states the adopted startup terminal, the title, the fallback, and the branch-deleting release, and `docs/verification/runtime-backends.md` says both are proven against the fake only.
- [X] The runner inventory guard `bin/fm-test-run.sh --check-coverage` is ok under `LC_ALL=C`; under `en_US.UTF-8` it exits 1 with a `comm` sort-order message that no test file of this feature can cause, so it is recorded as a runner locale issue and not fixed here.
- [X] Final full runs on the committed code, once and sequentially: `tests/fm-backend-orca.test.sh` 73 ok, 0 not ok, and `tests/fm-teardown-endpoint-safety.test.sh` 27 ok, 0 not ok (`tdd/cycle-log.md`).
- [ ] Live proof against a real Orca runtime (one live terminal after spawn, the Orca-made branch gone after a landed ship and kept after an unlanded one): not possible, no Linux Orca lab exists; this is the follow-up named in the plan and in the PR.

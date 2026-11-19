# Quality Checklist: Orca Live Test Lab

A checked box is a gate verified against the repository with the evidence beside it.
It is not a reviewer's approval of the requirements, and an unchecked box is explained.

- [X] Every acceptance scenario and edge case has a test or a recorded live observation, with no `NO_TEST` behavior (`tdd/test-list.md`, `tdd/verification.md`).
- [X] Every guard behavior was written test-first: `tdd/cycle-log.md` cycles 1 to 3 each record a red before the change; cycle 4 is a recorded characterization cycle with killed mutants.
- [X] No existing test was weakened, skipped, or excluded; the one existing test edited (`tests/fm-teardown-endpoint-safety.test.sh`, the two Orca-free teardown cases) failed on this host because the adapter's CLI fallback (merged slice P1-E) finds the installed Orca CLI, so it now pins `HOME` and `ORCA_CLI_BIN_DIR` the way `tests/fm-backend-orca.test.sh` already does, in its own commit with its expectation unchanged.
- [X] The lane refuses to run unless `FM_ORCA_LIVE_E2E=1`, and refuses an `ORCA_USER_DATA_PATH` that is, contains, lies inside, or links to `~/.orca` or `~/.orca-remote`, or that is not fresh (A1 to A3, U1 to U7, U12).
- [X] Every mutating live step is preceded by the own-child proof, and signals go only to proven lab processes (A4, U8, U9).
- [X] Every Orca command runs through a launcher pinned to the lab data directory with the caller's other `ORCA_*` variables removed, and the runtime runs with its own home (A5, U10).
- [X] A real run created and removed only `fm-test-` objects by exact id, and left no lab process, directory, systemd scope, worktree, or branch.
- [X] The operator's runtime stayed running and its data directory was unchanged by a real run (path set compared before and after).
- [X] No adapter file under `bin/backends/` or other adapter behavior changed.
- [X] `bin/fm-lint.sh` is clean under the pinned ShellCheck 0.11.0, and `bin/fm-doc-audience-check.sh` is ok.
- [X] `bin/fm-test-run.sh --check-coverage` exits 0 with both tests classified.
- [X] `docs/verification/runtime-backends.md` records the dated version, commands, shapes, per-assertion slice mapping, findings, and what could not run.
- [ ] The scheduled non-blocking nightly workflow: not written, because a pinned runtime artifact, its license, and a mirror are unknown and a workflow could not honestly be made to fail soft; documented as a follow-up.

# Quality Checklist: Orca Spare Terminal

- [X] The adapter lists `terminal list --worktree id:<id> --json` only when the creation response names no terminal (A2, mutant M1).
- [X] A terminal named by the response (`terminal`, then spawned `startupTerminal`) is adopted exactly as before.
- [X] Only rows of the created worktree that are not orphaned and not unwritable are adopted (U2-U5, A5, mutants M2, M2b, M2c).
- [X] An unreadable list never fails the spawn (A4, mutant M3).
- [X] A pathless worktree closes the adopted terminal before the worktree is released (A6, mutant M4).
- [X] The adopted terminal is titled with the task name, and a failed title does not fail the spawn (U7, A7, mutant M5).
- [X] Teardown closes exactly the recorded terminal and lists nothing (A8).
- [X] The adapter's stdout contract and the task metadata fields are unchanged (U6).
- [X] The live lab asserts `liveTerminalCount=1` after spawn and zero leftovers after teardown, and was shown red against the previous adapter (A9).
- [X] `bin/fm-lint.sh` passes with ShellCheck 0.11.0 and actionlint 1.7.12.
- [X] `docs/orca-backend.md` and `docs/verification/runtime-backends.md` state the adoption, the list shape, and the live result.
- [X] The lab ran only inside its isolated runtime; the operator's Orca registration and data were not touched, and no lab process, directory, or scope remained.

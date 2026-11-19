# Quality Checklist: Orca Local Process Classifier

- [X] Every behavior test was seen failing for the right reason before its implementation (`tdd/cycle-log.md`).
- [X] A present terminal runs a harness reads `alive`, holds only shells reads `dead`, holds anything else reads `ambiguous` (A1 to A5, A14).
- [X] No uncertain case reads `alive` or `dead`: a selected remote runtime, no process table, no local carrier, and an unlistable table are `unverified` or `unreadable` (A6 to A8).
- [X] A missing or unreadable endpoint keeps its verdict and the process table is not trusted (A9).
- [X] The classifier adds no `orca` call beyond the presence read and reads no native Orca agent state.
- [X] `fm_control_backend_state_verified` is unchanged, so `exit`, `relaunch`, reclaim, and secondmate restart stay refused on Orca (A10).
- [X] No other backend, reclaim, or control verb was touched.
- [X] `bin/fm-lint.sh` passes with ShellCheck 0.11.0; `bin/fm-doc-audience-check.sh` passes.
- [X] `docs/orca-backend.md`, the backend and control-library headers, and `docs/verification/runtime-backends.md` are updated.
- [X] The live lab ran only in its isolated runtime with a pinned `HOME` and left nothing behind (its final inventory assertion held).

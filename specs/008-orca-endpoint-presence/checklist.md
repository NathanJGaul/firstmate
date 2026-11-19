# Quality Checklist: Orca Endpoint Presence

- [X] Every behavior test was seen failing for the right reason before its implementation (`tdd/cycle-log.md`).
- [X] A live terminal reads present, and an exited, closed, or stale one reads missing, in the adapter, the backend, the digest, and crew state (A1 to A5, A13).
- [X] No failed read is ever missing: no CLI, invalid JSON, another error code, and contradictory records are unreadable (U2, U4).
- [X] The presence read is one read-only `terminal show` naming the terminal (U3), and crew state reads it once.
- [X] `fm_control_backend_state_verified` is unchanged, so `exit`, `relaunch`, and secondmate restart stay refused on Orca (A6).
- [X] No other backend, process classifier, reclaim, or control verb was touched.
- [X] `bin/fm-lint.sh` passes with ShellCheck 0.11.0 and actionlint 1.7.12; `bin/fm-doc-audience-check.sh` passes.
- [X] `docs/orca-backend.md`, the backend and control-library headers, and `docs/verification/runtime-backends.md` are updated.
- [X] The live lab ran only in its isolated runtime with a pinned `HOME` and left nothing behind (its final inventory assertion held).

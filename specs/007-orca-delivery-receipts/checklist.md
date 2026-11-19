# Quality Checklist: Orca Delivery Receipts

- [X] Every behavior test was seen failing for the right reason before its implementation (`tdd/cycle-log.md`).
- [X] The no-capability path issues the same sends and reads in the same order after one `orca status --json` read (U13, A6, M1).
- [X] A replay carries the first receipt's request id and the same text, and the text is never typed twice (U4, U6, M2, M6).
- [X] Only `terminal_not_writable` and `terminal_handle_stale` are read as a gone terminal, and both were observed live (A12, M3, M4).
- [X] A gone terminal exits nonzero so the four other callers of `fm_backend_send_text_submit` read a failed send without a change.
- [X] No change to `fm_backend_agent_state`, any other backend, or the ring ladder.
- [X] `bin/fm-lint.sh` passes with ShellCheck 0.11.0 and actionlint 1.7.12; `bin/fm-doc-audience-check.sh` passes.
- [X] `docs/orca-backend.md`, `docs/configuration.md` (`FM_ORCA_SUBMIT_WAIT`), and `docs/verification/runtime-backends.md` are updated.
- [X] The live lab ran only in its isolated runtime and left nothing behind (its final inventory assertion held).

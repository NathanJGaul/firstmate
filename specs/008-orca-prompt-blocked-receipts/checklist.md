# Quality Checklist: Orca Prompt-Blocked Receipts

- [X] Every behavior test was seen failing for the right reason first, except the hook-less characterization (`tdd/cycle-log.md`).
- [X] `agent_prompt_blocked` is its own class; the gone set is still exactly `terminal_not_writable` and `terminal_handle_stale`.
- [X] A parked prompt is sent to once: no replay, no Enter, no retype.
- [X] The ring returns 2, never 3, and names the prompt on stderr.
- [X] No change without the receipt capability, to any other backend, or to `bin/fm-send.sh`.
- [X] `bin/fm-lint.sh` and `bin/fm-doc-audience-check.sh` pass.
- [X] `docs/orca-backend.md` and `docs/verification/runtime-backends.md` are updated.
- [X] The lab ran only in its isolated runtime with a pinned `HOME` and removed its own directories.

# Implementation Plan: Orca Prompt-Blocked Receipts

**Spec**: `specs/008-orca-prompt-blocked-receipts/spec.md`

## Design

1. `fm_backend_orca_receipt_class` (bin/backends/orca.sh): add a `BLOCKED` check beside `GONE`. `ok:false` with `agent_prompt_blocked` prints `blocked<TAB>agent_prompt_blocked`. Update the class list in its header.
2. `fm_backend_orca_send_text_receipt`: a `blocked)` case before `*)`: write the stderr message, print `prompt-blocked`, return 1. It is reached on the first send and on any replay.
3. `fm_task_inbox_ring` (bin/fm-task-inbox-lib.sh): after the send, `prompt-blocked` writes a stderr line and returns 2; update the header's description of return 2.
4. Header comments in `bin/backends/orca.sh` and `fm_backend_send_text_submit` (bin/fm-backend.sh) name the verdict.
5. `docs/verification/runtime-backends.md`: the recorded `agent_prompt_blocked` and hook-less shapes. `docs/orca-backend.md` doorbell paragraph gets one line.
6. Lab: `tests/fm-backend-orca-smoke.test.sh` A12 gains a step that sends text plus Enter to a dialog-printing fake agent and asserts the refusal code (Appendix B recipe: the trust-dialog flag).

## Files

`bin/backends/orca.sh`, `bin/fm-task-inbox-lib.sh`, `bin/fm-backend.sh` (comment), `tests/fm-backend-orca.test.sh`, `tests/fm-task-inbox.test.sh`, `tests/fm-backend-orca-smoke.test.sh`, `docs/`.

## Compatibility

A runtime without `terminal.prompt-delivery.v1` never reaches the receipt path. Other backends are untouched; the four other callers of `fm_backend_send_text_submit` already read a nonzero exit as a failed send.

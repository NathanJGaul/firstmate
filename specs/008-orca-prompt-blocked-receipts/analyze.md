# Analysis: Orca Prompt-Blocked Receipts

Spec, plan, tasks, and tests agree.

- FR-001, FR-004, FR-005: `fm_backend_orca_receipt_class`; class matrix.
- FR-002: the `blocked)` case in `fm_backend_orca_send_text_receipt`; U2, U3, A1.
- FR-003: `fm_task_inbox_ring`; A2.
- FR-006: lab step A12 and `docs/verification/runtime-backends.md`.
- FR-007: only the listed scripts, tests, and docs changed; `bin/fm-send.sh` needed no edit because the adapter's stderr passes through (A1).

Deviation from the report's wording: the report suggested ring result 1 (skipped); the task statement asks for a failure, and 1 would print the wrong reason in `fm-send` ("composer holds pending text"), so the ring returns 2 (research D1).

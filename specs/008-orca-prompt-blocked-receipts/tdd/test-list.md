---
feature: 008-orca-prompt-blocked-receipts
loop: outside-in
profile: .specify/memory/tdd-profile.md
---

# Test List: Orca Prompt-Blocked Receipts

| id | behavior | traces | state | test |
| -- | -------- | ------ | ----- | ---- |
| A1 | A typed `fm-send` to a terminal parked on a prompt exits nonzero, names the blocked prompt, and is not called unconfirmed | US1.3 | DONE | `tests/fm-backend-orca.test.sh::test_fm_send_typed_names_a_blocked_prompt` |
| A2 | The ring returns 2 (not 3) for a blocked prompt, prints a stderr line, and sends once | US1.4, FR-003 | DONE | `tests/fm-task-inbox.test.sh::test_ring_reports_a_blocked_orca_prompt_as_a_failed_ring` |
| U1 | The class matrix maps `agent_prompt_blocked` to `blocked`, keeps both gone codes `gone`, and a hook-less accepted answer with a warning to `accepted` | FR-001, FR-004, FR-005 | DONE | `tests/fm-backend-orca.test.sh::test_receipt_class_matrix` |
| U2 | A blocked first send prints `prompt-blocked`, exits 1, names terminal, code, prompt, and nothing delivered, with exactly one send and no Enter | US1.1, US1.2, FR-002 | DONE | `tests/fm-backend-orca.test.sh::test_receipt_blocked_prompt_is_prompt_blocked` |
| U3 | A blocked replay gives the same verdict and sends nothing further | US1.5 | DONE | `tests/fm-backend-orca.test.sh::test_receipt_blocked_replay_is_prompt_blocked` |
| U4 | A hook-less accepted receipt is replayed by id and finishes on the composer | US3.1, FR-005 | DONE | `tests/fm-backend-orca.test.sh::test_receipt_hookless_accepted_is_replayed_by_id` |

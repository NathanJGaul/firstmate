# Feature Specification: Orca Prompt-Blocked Receipts

**Feature Branch**: `fm/firstmate-orca-receipts-prompt-blocked`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Receipts follow-up R1 from the Orca agentic CLI scout report: a text-plus-Enter send to an agent parked on a trust or permission prompt is refused by Orca with `agent_prompt_blocked`, which the merged receipts code counts as a plain failure.

## Overview

Orca 1.4.261 refuses `terminal send --text ... --enter` when the agent in the terminal is showing a permission or trust prompt.
It answers `ok:false` with `error.code = "agent_prompt_blocked"` and tells the caller to send the text and Enter as separate commands and to re-issue the exact command with `--retry-request <id>`.
Nothing was typed.
The delivery-receipts code (specs/007) reads every `ok:false` answer except the two gone codes as a generic failure, so the ring reports "doorbell did not reach" with no cause and a typed `fm-send` says only "send failed".
The refusal is a safety gain, because a doorbell typed into a parked dialog would press Enter on its default choice.
This feature names it, so the operator sees why the send did not land and the code never mistakes it for a dead terminal.

The same report notes that `turn_started` depends on Orca's agent hooks: a hook-less agent answers `stages:["input_accepted"]` with a warning and `observation:"supported"`.
That answer already takes the accepted-and-replay path; this feature pins it with a fixture.

## User Scenarios and Testing

### User Story 1 - A blocked prompt is named, not mistaken for a dead terminal (Priority: P1)

The operator steers a worker on Orca that is parked on a trust or permission prompt.

**Acceptance Scenarios**:

1. **Given** a receipt send answered `agent_prompt_blocked`, **When** the adapter returns, **Then** it prints the verdict `prompt-blocked`, exits 1, and names the terminal, the runtime code, and that a permission or trust prompt is showing and nothing was delivered.
2. **Given** that refusal, **When** the adapter returns, **Then** it has sent exactly once: no replay, no Enter-only key, no second send.
3. **Given** a typed `fm-send` to such a terminal, **When** it runs, **Then** it exits nonzero, prints the blocked-prompt message, and does not call the delivery unconfirmed.
4. **Given** the doorbell ring for such a terminal, **When** it runs, **Then** it returns 2 (the failed-ring result, so the watcher's bounded re-ring still applies), never 3 (dead), and prints a stderr line naming the blocked prompt.
5. **Given** a replay by request id that is itself answered `agent_prompt_blocked`, **When** the adapter returns, **Then** the result is the same blocked verdict.

### User Story 2 - The gone codes and other failures keep their meaning (Priority: P1)

1. `terminal_not_writable` and `terminal_handle_stale` stay `gone` (verdict `terminal-gone`, ring 3).
2. Every other `ok:false` code stays `send-failed`.

### User Story 3 - A hook-less agent is an accepted delivery (Priority: P2)

1. **Given** a send answered `stages:["input_accepted"]`, a warning, and `observation:"supported"` with a request id, **When** the adapter runs, **Then** the class is `accepted`, the receipt is replayed by id within the budget, and the composer decides the verdict afterwards, exactly as for any accepted receipt.
2. The warning field changes nothing.

## Requirements

- **FR-001**: `fm_backend_orca_receipt_class` MUST print class `blocked` with detail `agent_prompt_blocked` for that error code, and MUST NOT put it in the gone set.
- **FR-002**: The receipt send MUST print `prompt-blocked`, exit 1, and write a stderr message that names the terminal, the code, the blocked permission or trust prompt, and that nothing was delivered. It MUST NOT replay, press Enter, or retype.
- **FR-003**: `fm_task_inbox_ring` MUST return 2 for `prompt-blocked`, MUST NOT return 3, and MUST write a stderr line naming the blocked prompt.
- **FR-004**: The gone set stays exactly `terminal_not_writable` and `terminal_handle_stale`.
- **FR-005**: A hook-less accepted receipt (input accepted, supported, a warning, no `turn_started`) MUST behave as `accepted`.
- **FR-006**: `docs/verification/runtime-backends.md` MUST record the observed shapes, and the live lab MUST record the refusal from a dialog-printing fake agent.
- **FR-007**: No other backend, no `bin/fm-send.sh` edit unless a test shows one is needed, and nothing changes on a runtime without the receipt capability.

## Edge Cases

- A refusal on the first send: nothing was typed, so no composer read is made.
- A refusal during a replay: the earlier send was accepted without a turn, so the blocked verdict reports the dialog and still types nothing.
- Orca's advice to send text and Enter separately is not followed, because that would type into the dialog.

## Out of Scope

Answering the dialog, Escape delivery, agent-state proof, any other Orca verb.

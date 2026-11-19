# Feature Specification: Orca Delivery Receipts

**Feature Branch**: `fm/firstmate-orca-delivery-receipts`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Use Orca's delivery receipts for steering doorbells and text sends so a lost send is told apart from a delivered one (slice P2-D of the Orca evaluation plan, section 5.2 row 11).

## Overview

On Orca, a doorbell or a typed text send is two blind steps: write the literal text, then press Enter and read the composer back.
The read-back classifies the screen, and for the doorbell the verdict is discarded by design, so a send that Orca accepted, a send that Orca could not submit, and a send into a terminal that no longer exists all look alike.
A dead or missing terminal is the worst case: the adapter reports a failed send, the ring reports "doorbell did not reach", and the watcher re-rings a terminal that is never coming back.

Orca 1.4.261 reports delivery itself.
`terminal send --enter --wait-submit <seconds>` returns a receipt saying whether input was accepted, whether submission was observed, and whether a turn started, and `--retry-request <id>` replays a request without repeating the input.
The runtime lists the capability `terminal.prompt-delivery.v1` in `orca status --json` when it supports this.

This feature makes the Orca send path use those receipts when the runtime advertises them, keeps the current send loop untouched as the fallback, and turns a dead or missing terminal into a clear, specific failure instead of an assumed delivery.
It does not build the full agent-state proof that tells a live agent from a bare shell (a later slice).

## User Scenarios & Testing

### User Story 1 - A send is confirmed by Orca's own receipt (Priority: P1)

The operator steers a worker running on Orca, or the watcher rings its doorbell, and the Orca runtime supports delivery receipts.

**Why this priority**: The receipt is the only real evidence a send landed; everything else is a screen guess.

**Independent Test**: Run the adapter's text-submit against a fake `orca` whose status lists the receipt capability and whose `terminal send` returns a submitted receipt, and read the verdict and the commands issued.

**Acceptance Scenarios**:

1. **Given** a runtime that lists the receipt capability, **When** text is sent, **Then** one `terminal send` carrying the text, the enter flag, and a wait-submit window is issued and the composer is not read.
2. **Given** that send returns a receipt showing submission observed, **When** the adapter returns, **Then** its verdict is `empty`, which callers already read as confirmed delivery.
3. **Given** a receipt showing the input was accepted and a turn started, **When** the adapter returns, **Then** the verdict is `empty`.

---

### User Story 2 - An unsubmitted send is retried, not repeated (Priority: P1)

The receipt says Orca took the input but did not observe a submission.

**Why this priority**: Retyping would duplicate text in the composer; the receipt carries a request id exactly so a replay is safe.

**Independent Test**: Fake `orca` returning a not-submitted receipt with a request id on the first send and a submitted receipt on the replay.

**Acceptance Scenarios**:

1. **Given** a not-submitted receipt carrying a request id, **When** the adapter retries, **Then** it replays with that request id and the same text, within the caller's retry budget, never as a fresh unnumbered send.
2. **Given** the replay returns a submitted receipt, **When** the adapter returns, **Then** the verdict is `empty`.
3. **Given** the retry budget is spent and every receipt still says not submitted, **When** the adapter returns, **Then** the verdict is `pending`, the existing "typed but unconfirmed" verdict, and nothing was sent as a new request.
4. **Given** a receipt that is unsupported for this terminal (a plain shell, no recognized agent), **When** the adapter returns, **Then** it falls back to the current composer-read loop for the submit rather than reporting a failure.

---

### User Story 3 - A dead or missing terminal is a clear failure (Priority: P1)

The recorded Orca terminal no longer exists or has exited.

**Why this priority**: Today the failure is silent: a literal text goes into nothing, the ring calls it a failed ring, and the watcher keeps ringing.

**Independent Test**: Fake `orca` answering `terminal send` with the runtime's terminal-not-found error, and one answering with an exited terminal.

**Acceptance Scenarios**:

1. **Given** the runtime answers that the terminal cannot take input (a closed terminal, an exited shell, or an unknown handle), **When** the adapter returns, **Then** its verdict is `terminal-gone`, it exits 1, and it names the terminal and the runtime's reason on stderr.
2. **Given** the verdict is `terminal-gone`, **When** the doorbell is rung, **Then** the ring result is 3 (skipped because the endpoint is gone), so the watcher escalates the unavailable endpoint directly instead of ringing again.
3. **Given** the verdict is `terminal-gone`, **When** `fm-send` types text, **Then** it exits non-zero with an error that names the terminal, says it is gone and nothing was delivered, and does not say "delivery unconfirmed".
4. **Given** a send that fails for any other reason (another runtime error code, an unreachable runtime, a malformed answer, input the runtime did not accept), **When** the adapter returns, **Then** the verdict stays `send-failed` and the terminal is not declared gone.

---

### User Story 4 - A runtime without receipts behaves exactly as today (Priority: P1)

The Orca runtime is older, or it reports no receipt capability, or its status cannot be read.

**Why this priority**: The receipt options are not guaranteed to exist; the existing path is verified and must not change.

**Independent Test**: Fake `orca` whose status lists no receipt capability, or fails; compare the commands issued with the current behavior.

**Acceptance Scenarios**:

1. **Given** a status without the receipt capability, **When** text is sent, **Then** the commands issued are byte-identical to today's literal send, composer reads, and Enter retries.
2. **Given** a status that fails or is not valid JSON, **When** text is sent, **Then** the same current path is used.
3. **Given** a receipt that reports an old host (`provider old-host`), **When** the adapter returns, **Then** it takes the same composer fallback as any unsupported receipt, because the command line itself already degrades for an old host.

---

### User Story 5 - The live runtime proves the shapes (Priority: P2)

A maintainer runs the opt-in live lab.

**Why this priority**: The fake receipts encode the shapes this feature assumes; only the real runtime can confirm them.

**Independent Test**: The lab's firstmate section sends to a live terminal and to a terminal it has closed, and records what Orca answered.

**Acceptance Scenarios**:

1. **Given** the lab runtime and a live terminal, **When** the adapter sends text, **Then** the lab records the real receipt shape and the verdict.
2. **Given** the same terminal after it is closed, **When** the adapter sends text, **Then** the lab records the real error shape and asserts the verdict is `terminal-gone`.
3. **Given** the run is complete, **Then** `docs/verification/runtime-backends.md` carries the dated shapes and the commands that refresh them.

### Edge Cases

- The capability list is large (about 300 entries) and read per send: the read must be bounded to one `orca status --json` call per send, and a failure of it means "no receipts", never a failed send.
- A request id is only ever replayed with the same text it first carried.
- The text may contain quotes, newlines, and leading `-`; it is passed as a single argument value exactly as today.
- A busy agent can accept input and queue it: a receipt that shows accepted input with a turn not yet started is not a failure.
- A recognized-agent receipt and a plain-shell receipt differ; the plain shell never reports submission, so it must not be treated as a lost send.
- Remote and non-Orca backends are unchanged.

## Requirements

### Functional Requirements

- **FR-001**: The Orca adapter MUST read the runtime's capability list from `orca status --json` and use receipts only when it lists `terminal.prompt-delivery.v1`.
- **FR-002**: With receipts, the adapter MUST send text with one `terminal send` carrying the text, the enter flag, and a bounded wait-submit window, and derive its verdict from the returned receipt.
- **FR-003**: A submitted receipt MUST yield the verdict `empty`; a not-submitted receipt MUST be retried with `--retry-request <id>` and the same text, within the caller's retry budget; an exhausted budget MUST yield `pending`.
- **FR-004**: A receipt the runtime marks unsupported for the terminal MUST fall back to the current send-and-read loop for the submit, without retyping text the receipt path already wrote.
- **FR-005**: A send the runtime answers with `terminal_not_writable` (closed or exited terminal) or `terminal_handle_stale` (unknown handle) MUST yield the verdict `terminal-gone`, exit 1, and a stderr message naming the terminal and the runtime's code.
- **FR-006**: Every other failure MUST yield `send-failed` with exit 0; the adapter MUST NOT infer a gone terminal from any answer other than those two codes.
- **FR-007**: Without the capability, or when status cannot be read, the sends and reads MUST be the current loop's, in the same order, after one `orca status --json` read.
- **FR-008**: `fm_task_inbox_ring` MUST map `terminal-gone` to its existing "endpoint gone" result (3) and MUST keep mapping `send-failed` to 2 and every other verdict to 0.
- **FR-009**: `fm-send`'s typed plane MUST surface a `terminal-gone` send as a failure whose message names the terminal, says it is gone and that nothing was delivered.
- **FR-010**: No change to the agent-state classifier, `fm_backend_agent_state`, or any non-Orca backend.
- **FR-011**: The live lab MUST exercise a send to a live and to a closed terminal and record the real response shapes in `docs/verification/runtime-backends.md`.

### Key Entities

- **Receipt**: the `result` object returned by `orca terminal send --enter --wait-submit`: input acceptance, a submission observation, a mutation record with a `requestId`, and a `replayed` flag.
- **Verdict**: the adapter's one-word answer to `fm_backend_send_text_submit`: `empty` (delivered), `pending` (typed, unconfirmed), `unknown`, `send-failed`, and now `terminal-gone`.

## Success Criteria

- **SC-001**: With fake receipts for started, not-started then started, not-started throughout, unsupported, and a gone terminal, the adapter returns `empty`, `empty`, the composer's verdict (`empty`, or `pending` when unreadable), the fallback's verdict, and `terminal-gone`.
- **SC-002**: A no-capability fake produces the exact command sequence recorded before this change.
- **SC-003**: The ring returns 3 for a gone terminal and the watcher's existing unavailable-endpoint escalation handles it.
- **SC-004**: The lab records one live receipt and one live terminal-gone answer, and its assertions pass.

## Assumptions

- The receipt and error shapes are the ones the lab recorded on 2026-11-18 and 2026-11-19 (`research.md`): `result.send.prompt{requestId, stages, provider, observation}`, `result.mutation{requestId, replayed}`, and `error.code`.
- The capability record that the Escape slice may add has not landed; this feature reads the capability list directly from `orca status --json` and the two will be reconciled on rebase.
- Out of scope: proving an agent is alive or dead, any change to `fm_backend_agent_state`, Escape delivery, and viewport capture.

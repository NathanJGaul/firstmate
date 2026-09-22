# Feature Specification: Telegram Bot QR Control

## Overview

Firstmate needs an optional Telegram transport for remote control of one active session.
A local operator configures a bot token, pairs one Telegram user and chat by scanning a one-time deep-link QR code, and receives bounded status and decision information.
Telegram input is untrusted transport data and never becomes shell input.

## User Stories

### US1 - Configure and pair a phone (Priority: P1)

As an operator, I can configure a bot token locally and scan a QR code that opens the bot with a one-time expiring pairing token.

**Acceptance Scenarios**

1. Given a valid token and local home, when setup runs, then the token is stored only in gitignored home configuration and setup prints a Telegram deep-link plus QR representation.
2. Given an unexpired pairing token, when the paired phone opens the deep-link, then Telegram identity and chat identity are recorded and the pairing token is invalidated.
3. Given an expired, reused, or malformed pairing token, when Telegram sends `/start`, then the request is rejected and no identity is recorded.

### US2 - Receive safe remote control (Priority: P1)

As a paired operator, I can request status, open decisions, add notes, and steer a worker through existing owner scripts.

**Acceptance Scenarios**

1. Given a paired identity, when it sends `/status`, then Telegram receives a bounded status response derived from durable Firstmate records.
2. Given a paired identity, when it sends `/decisions`, then Telegram receives bounded open decision information without merge or destructive controls.
3. Given a paired identity, when it sends `/note <text>`, then the text is durably queued through the existing inbox owner script and Telegram receives the resulting note identity.
4. Given a paired identity, when it sends `/steer <worker> <text>`, then the text is delivered through the existing steering owner script only when the target and text pass validation.
5. Given an unpaired or mismatched user or chat, when it sends any control command, then Telegram receives a rejection and no Firstmate state changes.

### US3 - Operate reliably as an optional transport (Priority: P1)

As an operator, I can leave Telegram polling enabled while Firstmate remains authoritative and recover safely from duplicate or interrupted Telegram updates.

**Acceptance Scenarios**

1. Given polling is enabled, when the Telegram API returns updates, then updates are processed through a local outbound long poll and no inbound webhook is required.
2. Given an update id was already processed, when it is delivered again, then no command executes twice and one durable inbound record remains authoritative.
3. Given Telegram is unavailable or returns malformed data, when polling runs, then the poll reports a bounded failure without executing input or corrupting pairing state.
4. Given outbound responses are sent, then inbound and outbound records remain durably persisted with bounded content and update identity.

## Functional Requirements

- **FR-001**: Provide local setup that validates a Telegram bot token, stores it with restrictive permissions, and prints a bot deep link and scannable QR representation.
- **FR-002**: Generate pairing nonces with one-time use, bounded expiry, and rotation after successful pairing.
- **FR-003**: Bind accepted commands to both Telegram user identity and chat identity recorded during pairing.
- **FR-004**: Poll Telegram using the Bot API `getUpdates` long-poll endpoint from the local session; do not expose an inbound webhook.
- **FR-005**: Persist a durable Telegram inbox by update id before deduplication or command execution, then deduplicate updates without losing an unfinished effect.
- **FR-006**: Persist inbound update records and outbound response records under the operational home state directory.
- **FR-007**: Support only `/status`, `/decisions`, `/note`, and `/steer`; route each through existing read or owner scripts.
- **FR-008**: Reject unpaired, mismatched, malformed, empty, oversized, and unsafe command inputs without invoking owner scripts.
- **FR-009**: Exclude merge, destructive, irreversible, credential, and security-sensitive authority from Telegram-only commands.
- **FR-010**: Keep token and pairing records in gitignored home configuration/state and support Linux, macOS, and Windows environments with Python standard library and shell-free subprocess boundaries. Windows uses the bundled Python polling worker and Python owner implementations instead of Unix shell runners.
- **FR-011**: Bound Telegram API responses to 256 KiB, command text to 4096 UTF-8 bytes, outbound message text to 4096 characters, owner calls to 20 seconds, and long-poll waits to 50 seconds.
- **FR-012**: Document setup, pairing, enablement, command surface, and limitations.

## Success Criteria

- **SC-001**: A fresh local home completes token setup and prints a deep link without admin privileges.
- **SC-002**: A valid QR pairing succeeds once, and every expired or replayed pairing attempt is rejected.
- **SC-003**: Every supported command reaches its documented owner boundary, while rejected commands produce zero owner-script invocations.
- **SC-004**: Replaying one Telegram update id produces at most one durable command effect and one inbound record.
- **SC-005**: Polling uses no listening socket or webhook and returns within its configured timeout when Telegram is unavailable.
- **SC-006**: Focused behavioral tests cover pairing, identity checks, deduplication, command allow-listing, persistence, and API failure handling.

## Edge Cases

- Token validation succeeds but local state publication fails.
- Pairing expires between QR generation and `/start` handling.
- Telegram delivers the same update id with different content.
- Telegram returns an oversized or malformed JSON response.
- A worker disappears between `/steer` validation and owner-script invocation.
- A command contains shell metacharacters, control bytes, path traversal, or a destructive keyword.
- A response exceeds Telegram's message limit.

## Out of Scope

- Telegram webhooks, inbound listening servers, group administration, file uploads, arbitrary shell commands, merge approval, destructive actions, credentials, and security-sensitive actions.

## Assumptions

- The operator creates the bot with BotFather and supplies its token locally.
- `python3` is available because Firstmate already uses it for machine-readable state.
- The bundled Python renderer always prints a QR representation alongside the exact deep link.

---
feature: telegram-bot-qr
planned_at: 2026-09-21
loop: outside-in
suite_baseline: green focused; OMP-only regression excludes non-OMP live adapters
---

# TDD Test List: Telegram Bot QR Control

## Outer Loop

| ID | Behavior | Traces | Kind | Runner | State | Test |
|---|---|---|---|---|---|---|
| U1 | Setup stores token and emits bot deep link with one-time pairing nonce | SC-001, SC-002, FR-001, FR-002 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |
| U2 | Paired chat receives bounded safe command results and rejects mismatched identities | SC-003, FR-003, FR-007, FR-008, FR-009 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |
| U3 | Polling persists updates, deduplicates replay, and handles API failure without unsafe effects | SC-004, SC-005, SC-006, FR-004, FR-005, FR-006, FR-011 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |

## Inner Loop

### `bin/fm-telegram.py`

| ID | Behavior | Traces | Kind | Runner | State | Test |
|---|---|---|---|---|---|---|
| U4 | Pairing accepts exact unexpired nonce once and rotates nonce after success | FR-002, FR-003 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |
| U5 | Pairing rejects expired, malformed, and replayed nonce without identity mutation | FR-002, FR-008 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |
| U6 | Command parser rejects control bytes, oversized values, unknown commands, and unsafe worker IDs | FR-007, FR-008, FR-009, FR-011 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |
| U7 | Duplicate update ID skips owner dispatch while preserving one inbound record | FR-005, FR-006 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |
| U8 | API timeout and malformed response preserve pairing and records a bounded failure | FR-006, FR-011 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |

### `bin/fm-procevent-telegram.sh`

| ID | Behavior | Traces | Kind | Runner | State | Test |
|---|---|---|---|---|---|---|
| U9 | Telegram process-event adapter classifies captured poll result and suppresses routine poll wakeups | FR-004, FR-009 | example | `bin/fm-test-run.sh tests/fm-telegram.test.sh` | GREEN | `tests/fm-telegram.test.sh` |

## Invariants and edge cases still to place

- Bot token never appears in inbound, outbound, or QR records.
- Update offset advances only after durable update processing.
- Telegram response text stays within message bounds.

## Out of scope

- Webhooks, arbitrary shell, merge approval, destructive actions, credential actions, and security-sensitive actions.

## Verification commands

- Focused: `bin/fm-test-run.sh tests/fm-telegram.test.sh`
- OMP-only regression: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`
- Lint: `bin/fm-lint.sh`

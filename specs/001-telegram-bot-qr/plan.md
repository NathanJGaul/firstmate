# Implementation Plan: Telegram Bot QR Control

## Technical Context

- Language: Python 3 standard library for cross-platform network, JSON, hashing, subprocess, and file handling.
- Existing boundaries: `bin/fm-inbox.sh`, `bin/fm-send.sh`, `bin/fm-bearings-snapshot.sh`, and `bin/fm-procevent.sh`.
- External service: Telegram Bot API over outbound HTTPS long polling through `urllib.request` with a 30-second default timeout and 50-second maximum.
- QR output: optional `qrencode` ANSI output with exact deep-link fallback.
- Persistence: home-local `config/telegram-bot-token` and `state/telegram/` records, all mode 0600.
- Tests: existing Bash behavior runner with Python fixture HTTP server.

## Constitution Check

- TDD: behavior tests precede implementation and record red/green evidence.
- Boundary safety: Telegram text is validated and passed as argv or stdin, never shell-evaluated.
- Simplicity: one Python implementation and one adapter wrapper; no new dependency.
- Privacy: bot token never enters records or outbound messages.

## Architecture

`bin/fm-telegram.py` owns configuration, pairing, polling, command dispatch, persistence, and Telegram HTTP calls.
`bin/fm-procevent-telegram.sh` is the process-event adapter that registers one local outbound poll source and invokes `fm-telegram.py poll --once` without a shell.
A polling cycle reads one bounded `getUpdates` response, deduplicates update IDs, persists inbound records, validates pairing identity, invokes only existing owner scripts, persists outbound responses, and sends responses through `sendMessage`.

## Data Model

- `config/telegram-bot-token`: one token line, mode 0600.
- `state/telegram/pairing.json`: schema, bot username, nonce hash/expiry, paired user ID, paired chat ID, and pairing time.
- `state/telegram/offset`: next update offset, mode 0600.
- `state/telegram/inbound/<update-id>.json`: bounded update envelope without bot token.
- `state/telegram/outbound/<sequence>.json`: destination, update ID, command, bounded text, API outcome, and timestamp.
- `state/telegram/errors/<sequence>.json`: bounded poll failure evidence.
- `state/telegram/processed/<update-id>`: exclusive pre-dispatch deduplication marker, mode 0600.

## Command Contract

- `/start <nonce>`: pairing only; accepted when nonce hash and expiry match and pairing is not already complete.
- `/status`: reads `fm-bearings-snapshot.sh --json` and returns bounded current durable status.
- `/decisions`: reads `fm-bearings-snapshot.sh --json --all-decisions` and returns bounded open decisions.
- `/note <text>`: calls `fm-inbox.sh note --request-id telegram-<update-id> --json -` with text on stdin.
- `/steer <worker> <text>`: validates worker and text, then calls `fm-send.sh <worker> <text>` through the owner boundary.

## Security and Failure Rules

- Token is read only from the home config file or explicit environment override for tests.
- Pairing compares exact string user and chat IDs and rotates the nonce after success.
- Update IDs are decimal integers and are processed once even when content differs on replay.
- Text rejects control bytes, line breaks, empty values, shell-looking command forms, and values above fixed bounds.
- Subprocess calls use argument arrays, fixed executable paths, bounded timeouts, and no shell.
- Telegram failures are recorded and do not mutate pairing or owner state.

## Implementation Phases

1. Add pairing/configuration and QR deep-link output.
2. Add polling, durable records, identity checks, and command dispatch.
3. Add process-event adapter and setup/enable/help documentation.
4. Add focused public-interface regression tests and run OMP-only validation.

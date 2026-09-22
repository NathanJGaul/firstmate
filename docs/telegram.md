# Telegram Remote Control

Telegram is an optional outbound transport for one active Firstmate home.
Firstmate polls Telegram with the Bot API `getUpdates` long-poll endpoint using a bounded 30-second timeout (maximum 50 seconds) and never opens an inbound webhook listener.

## Setup

Create a bot with BotFather, then run this from the Firstmate repository:

```sh
bin/fm-telegram.py setup --token '<bot-token>'
```

Setup validates the token with `getMe`, stores it in `config/telegram-bot-token` with mode `0600`, and prints a one-time pairing link plus a QR representation when `qrencode` is installed.
The exact deep link remains available when QR rendering is unavailable; no administrator privileges or package installation are required.

Scan the QR code or open the link in Telegram.
The link opens the bot with `/start <nonce>`.
The nonce expires after ten minutes, works once, and rotates after pairing.
Pairing binds both Telegram user ID and chat ID.

## Enable polling

```sh
bin/fm-telegram.py enable
```

Enablement registers one `telegram-bot` process-event source for the active home.
The existing process-event runner owns background execution, durable capture, wake publication, and restart recovery.
Disable it with:

```sh
bin/fm-telegram.py disable
```

## Commands

- `/status` reads bounded durable fleet status.
- `/decisions` reads bounded open decisions.
- `/note <text>` queues a note through `bin/fm-inbox.sh`.
- `/steer <worker> <text>` sends reversible worker text through `bin/fm-send.sh`.

Unknown commands, unpaired users, mismatched chats, control bytes, oversized text, and unsafe worker IDs are rejected.
Telegram-only control cannot merge, delete, perform destructive or irreversible actions, handle credentials, or approve security-sensitive work.
Telegram text is never evaluated by a shell.

## Records and limits

Inbound updates, processed-update markers, outbound responses, poll errors, and the next update offset live under `state/telegram/`.
The pairing record stores only a hash of the active nonce; the raw nonce appears only in the printed deep link.
Bot tokens never enter those records.
- A single Telegram response is limited to 256 KiB, command text to 4096 UTF-8 bytes, and outbound message text to 4096 characters.
- Owner-script calls are limited to 20 seconds, and one `getUpdates` request waits up to 50 seconds.
Repeated Telegram update IDs do not execute commands twice.

Polling errors are recorded as bounded local evidence and do not mutate pairing state.
A temporary Telegram outage clears on a later process-event retry.

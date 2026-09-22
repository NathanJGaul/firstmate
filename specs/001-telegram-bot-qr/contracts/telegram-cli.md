# Telegram CLI Contract

## Setup

`bin/fm-telegram.py setup --token <token>` validates and stores the token, calls `getMe`, creates pairing state, and prints the bot deep link plus QR output when available.

## Enablement

`bin/fm-telegram.py enable` validates configuration and registers source `telegram-bot` through `bin/fm-procevent.sh register telegram telegram-bot -- <adapter> poll`.

`bin/fm-telegram.py disable` retires source `telegram-bot` through the owner script.

## Polling

`bin/fm-telegram.py poll --once` performs one bounded outbound `getUpdates` call, processes all bounded updates, advances offset only after durable processing, and returns nonzero for malformed input or network/API failure.

## Output

Human output excludes token values.
Machine-readable setup and poll summaries use JSON only when `--json` is supplied.

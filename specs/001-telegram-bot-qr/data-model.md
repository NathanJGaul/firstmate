# Telegram Data Model

## Home Configuration

`config/telegram-bot-token` stores exactly one non-empty Bot API token line with mode 0600.

## Pairing Record

`state/telegram/pairing.json` stores `schema`, `bot_username`, `nonce_hash`, `nonce_expires_at`, `paired_user_id`, `paired_chat_id`, `paired_at`, and the update ID of a polling pairing effect when present.

Pairing starts with empty identity fields and never stores the raw nonce.
Successful pairing atomically replaces the nonce hash with a fresh nonce hash and records both identities.

## Update Records

`state/telegram/inbox/<update-id>.json` stores the durable update envelope and effect state before deduplication, owner dispatch, or offset publication.
`state/telegram/inbound/<update-id>.json` stores schema, update ID, receipt time, bounded command text, and identity IDs.
`state/telegram/processed/<update-id>` is an empty exclusive marker claimed after the inbox record; a marker never suppresses an unfinished inbox effect.
`state/telegram/offset` stores the next Telegram offset as a decimal integer.

`state/telegram/outbound/<sequence>.json` stores schema, update ID, chat ID, command, bounded response text, receipt time, and API result.
`state/telegram/errors/<sequence>.json` stores a bounded poll failure and timestamp without bot credentials.
Bot tokens never appear in any record.

## Limits

Update JSON: 256 KiB.
Command text: 4096 UTF-8 bytes.
Telegram response text: 4096 Unicode characters.
Polling timeout: 30 seconds by default, bounded to 50 seconds.
Pairing expiry: 10 minutes by default, bounded to 24 hours.

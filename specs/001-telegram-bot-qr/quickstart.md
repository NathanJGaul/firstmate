# Telegram Validation Quickstart

1. Create a Telegram bot with BotFather and copy its token.
2. Run `bin/fm-telegram.py setup` from the Firstmate repository and paste the token at the prompt.
3. Scan the printed QR code or open the printed `https://t.me/<bot>?start=<nonce>` link.
4. Run `bin/fm-telegram.py poll --once` after sending `/status` from the paired chat.
5. Confirm the response arrives and `state/telegram/inbound/` plus `state/telegram/outbound/` contain records without the token.
6. Replay the same Telegram update fixture and confirm no duplicate owner action.
7. Run `bin/fm-test-run.sh tests/fm-telegram.test.sh`.

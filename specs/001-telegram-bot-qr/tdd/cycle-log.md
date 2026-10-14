# TDD Cycle Log: Telegram Bot QR Control

## Baseline

- Date: 2026-09-21
- Suite command: `bin/fm-test-run.sh tests/fm-telegram.test.sh`
- Initial red: `bin/fm-test-run.sh tests/fm-telegram.test.sh` failed because `bin/fm-telegram.py` did not exist.
- OMP-only constraint: non-OMP live adapter coverage excluded by captain instruction.

## U1-U3 Outer behaviors

- Red command: `bin/fm-test-run.sh tests/fm-telegram.test.sh`
- Red evidence: `bin/fm-telegram.py: No such file or directory`
- Green command: `bin/fm-test-run.sh tests/fm-telegram.test.sh`
- Green evidence: `FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0`
- Implementation: setup, pairing, polling, records, identity validation, and owner dispatch in `bin/fm-telegram.py`; adapter in `bin/fm-procevent-telegram.sh`.
- Refactor: restored subprocess output handling and moved pairing replay validation before paired-state rejection.
- Note: one combined outer test covers U1-U3, and the focused suite covers inner behaviors U4-U9 through public CLI and adapter entry points.

## Follow-up red-green evidence

- Red cause: the first implementation used `getUpdates` with `timeout=0`, persisted the raw pairing nonce, and allowed routine process-event polls to announce wakeups.
- Green command: `bin/fm-test-run.sh tests/fm-telegram.test.sh`
- Green evidence: `FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0`; nine behavior assertions passed, including long-poll timeout, deep-link `/start` pairing, parser rejection, error persistence, and process-event silence.
- Full OMP-only command: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`.
- Full-run evidence: the run exceeded approximately 35 minutes and was terminated with exit 143 after unrelated existing failures in harness and process-event tests; its captured output did not report a Telegram test failure.
- Relevant Telegram checks remain green: focused behavior suite, Telegram shell lint, Python syntax, adapter shell syntax, and documentation audience validation.
- OMP-only limitation: non-OMP live adapter coverage remains excluded by captain instruction.

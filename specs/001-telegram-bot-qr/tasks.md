# Tasks: Telegram Bot QR Control

## Phase 1: Setup

- [X] T001 Add Telegram test fixture and public-interface test entry in `tests/fm-telegram.test.sh`.
- [X] T002 Add Telegram configuration and setup documentation in `docs/telegram.md` and `README.md`.

## Phase 2: Foundational

- [X] T003 [P] [U1] Test token storage, mode, and QR deep-link output in `tests/fm-telegram.test.sh`.
- [X] T004 [P] [U1] Implement token configuration and pairing-state helpers in `bin/fm-telegram.py`.
- [X] T005 [U1] Implement setup command and one-time expiring pairing flow in `bin/fm-telegram.py`.

## Phase 3: Safe Remote Commands

- [X] T006 [P] [U2] Test paired identity validation and command allow-list behavior in `tests/fm-telegram.test.sh`.
- [X] T007 [P] [U2] Test status, decisions, note, and steer owner-script boundaries in `tests/fm-telegram.test.sh`.
- [X] T008 [U2] Implement bounded command parsing and identity checks in `bin/fm-telegram.py`.
- [X] T009 [U2] Implement owner-script dispatch for status, decisions, note, and steer in `bin/fm-telegram.py`.

## Phase 4: Polling and Durability

- [X] T010 [P] [U3] Test long polling, update deduplication, persistence, offsets, and API failures in `tests/fm-telegram.test.sh`.
- [X] T011 [U3] Implement outbound Bot API polling and bounded sendMessage calls in `bin/fm-telegram.py`.
- [X] T012 [U3] Implement inbound/outbound records, deduplication markers, and offsets in `bin/fm-telegram.py`.
- [X] T013 [U3] Add process-event Telegram adapter registration and lifecycle in `bin/fm-procevent-telegram.sh`.

## Phase 5: Polish

- [X] T015 Run focused Telegram tests, OMP-only regression validation, lint, and documentation audience checks; full regression was attempted and stopped on unrelated existing baseline failures recorded in `tdd/verification.md`.

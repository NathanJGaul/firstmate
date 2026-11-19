# Implementation Plan: Orca Delivery Receipts

**Branch**: `fm/firstmate-orca-delivery-receipts` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/007-orca-delivery-receipts/spec.md`

## Summary

`fm_backend_orca_send_text_submit` becomes two paths behind one capability check.
With `terminal.prompt-delivery.v1` in `orca status --json`, it sends once with `terminal send --text <t> --enter --wait-submit <s>`, reads the receipt, replays `--retry-request <id>` while the receipt stays unproven, and finishes with the existing proven-pending Enter retry.
Without the capability it runs today's literal-send-then-Enter loop unchanged.
A terminal Orca reports as gone makes the adapter print `terminal-gone` and exit nonzero.
`fm_task_inbox_ring` maps that word to its existing "endpoint gone" result, so the watcher's unavailable-endpoint escalation handles it, and `fm-send` names it on the typed plane.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell, with the same inline Node snippets the adapter already uses for JSON

**Primary Dependencies**: none new; the fake `orca` CLI already used by `tests/fm-backend-orca.test.sh` and the opt-in lab

**Storage**: none; the steering-inbox record format, ring ladder, and wake queue are unchanged

**Testing**: extend `tests/fm-backend-orca.test.sh` (fake receipts), `tests/fm-send.test.sh` and the inbox ring tests for the ring and `fm-send` mappings, and `tests/fm-backend-orca-smoke.test.sh` (live lab); run with `bin/fm-test-run.sh <file>`

**Target Platform**: Linux and macOS

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; the no-capability path issues the same sends and reads in the same order after one extra `orca status --json`; no change to any other backend; the lab runs only inside its isolated runtime

**Scale/Scope**: three scripts, three test files, one verification record

## Constitution Check

The constitution is the unfilled template, so there are no gates beyond the TDD principle in `.specify/memory/tdd-profile.md` and `specs/007-orca-delivery-receipts/tdd/`.

## Design

### D1: One capability read per send, in the adapter

`fm_backend_orca_has_capability <name>` runs `orca status --json` once and exits 0 only when `result.runtime.capabilities` is an array containing the name.
A failed call, invalid JSON, or a missing list is "not supported", never an error.
It is deliberately not cached: a runtime restarted under a new version must be re-read, and the call is cheap against a wait-submit window.
The Escape slice may add a shared capability record; this helper is the one place to switch over on rebase.

### D2: Classify a receipt in one place

`fm_backend_orca_receipt_class` reads one `terminal send` JSON answer on stdin and prints `<class> <requestId>`:

| class | meaning | source |
| --- | --- | --- |
| `started` | the receipt's stages include `turn_started` | `result.send.prompt.stages` |
| `accepted` | input accepted, observation `supported`, no turn yet, a request id present | `result.send.accepted`, `prompt.observation`, `mutation.requestId` |
| `unsupported` | input accepted but the terminal is a plain shell, an unrecognized agent, or an old host | `prompt.observation != supported`, or no `prompt` |
| `gone` | the runtime answered that the terminal cannot take input: closed, exited, or an unknown handle | `error.code` in the gone set |
| `failed` | anything else: `ok:false` with another code, invalid JSON, a missing answer | |

The gone set is exactly the two codes the lab observed: `terminal_not_writable` for a terminal that was closed or whose process exited, and `terminal_handle_stale` for a handle the runtime does not know.
No code outside that observed set is inferred to mean gone, and neither code is treated as proof about the agent inside a live terminal: they say only that this recorded endpoint cannot take input.

### D3: The receipt path

```text
send once:   terminal send --terminal T --text TEXT --enter --wait-submit W --json
loop over the caller's retry budget (R attempts in total, the first send included):
  started      -> empty
  gone         -> stderr names T and the code; print terminal-gone; exit 1
  failed       -> stderr from the runtime; print send-failed; (adapter exits 0 as today)
  unsupported  -> settle, read the composer once; proven pending -> the existing Enter retry core; else its verdict
  accepted     -> replay: same command plus --retry-request <id>, same TEXT, same W
after the budget with the receipt still unproven:
  read the composer once: empty -> empty (Orca accepted it and it left the composer);
                          proven pending -> the existing Enter retry core (a swallowed Enter, never a retype);
                          anything else -> pending (Orca accepted the input; the screen cannot confirm it)
```

`W` defaults to 2 seconds and is tunable with `FM_ORCA_SUBMIT_WAIT`.
The worst case is `R x W`, which is 4 seconds for the doorbell and 6 for a typed send.
The replay never types text again: the receipt id is bound to the payload, and a replay only observes it.

### D4: The adapter's contract change is exit status, not a new word everyone must learn

`bin/backends/orca.sh` prints `terminal-gone` and exits 1 for a gone terminal.
Four other callers of `fm_backend_send_text_submit` (`bin/fm-control.sh`, `bin/fm-supervise-daemon.sh`, and `bin/fm-spawn.sh` twice) test only `send-failed` or a nonzero exit, so a gone terminal reads as a failed send to each of them without a change.
Only `fm_task_inbox_ring` and `fm-send` read the word.

### D5: Ring and `fm-send`

`fm_task_inbox_ring` keeps the verdict when the send exits nonzero: a `terminal-gone` verdict returns 3 (the existing positively-gone result, nothing typed), any other nonzero exit returns 2, and every other verdict is unchanged.
The watcher already routes a 3 to `inbox_steer_escalate_unavailable`, and `fm-send` already prints its "agent has exited" notice for a 3.
`fm-send`'s typed plane keeps its generic send-failed exit 1 and adds one line naming a gone terminal so the operator is not told "send failed" with no reason.

### D6: The live lab proves the shapes

The lab gains step A12, run in the Orca-level section: a send with receipts to a plain shell, to a closed terminal, and to a shell that has exited, recording each real answer.
The firstmate section sends a typed text to the live task terminal and then to a closed one through the real scripts.
The recorded codes decide the gone set in D2 before the parser is written; the dated shapes go into `docs/verification/runtime-backends.md`.

## Risks

- A recognized agent that is busy queues the input, so a turn does not start within the window: the receipt stays `accepted`, the composer reads `empty`, and the verdict is `empty`; a composer that still holds text yields `pending`, so a busy worker is never reported as a failed send.
- `terminal_handle_stale` also appears in the runtime for a handle bound to an older process incarnation.
  Either way the recorded endpoint will never accept this input again, so treating it as gone is right; the lab showed handles survive a runtime restart, so a restart alone does not produce it.
- A gone verdict sends the watcher to its direct unavailable-endpoint escalation instead of three more rings; a terminal that is only momentarily not writable would cost one early wake to firstmate, not lost work.
- The real turn-start receipt is unobserved in the lab, which has no agent that starts a turn; the parser trusts the CLI's documented `turn_started` stage and the lab records the not-started case.

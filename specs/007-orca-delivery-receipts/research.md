# Research: Orca Delivery Receipts

## Receipt shape (Orca 1.4.261, read from the lab and the CLI help)

- `orca terminal send --terminal <h> --text <t> --enter --wait-submit <s> --json` returns `result.send.{accepted, prompt}`, `result.mutation.{requestId, replayed}`, and `result.warnings[]`.
- `result.send.prompt` carries `requestId`, `stages[]`, `provider`, and `observation`.
  `stages` is `["input_accepted"]`, and gains `"turn_started"` once the agent's turn is proven.
  `observation` is `supported` for a recognized agent and `unsupported` for a plain shell or an old host (`provider: "old-host"`, `requestId: "unsupported-old-host"`).
- A default send observes for 0 seconds, so a receipt that stops at `input_accepted` means "unproven", not "failed".
  `--wait-submit <s>` observes the same accepted prompt for up to `s` seconds and never resends.
- `--retry-request <id>` replays an earlier request: the result is the same prompt's current receipt, `mutation.replayed` is `true`, and the input is not repeated.
  The id is bound to the payload and the exact terminal process incarnation, so it is only valid with the same text and terminal.
- The lab drove a fake agent named for a recognized harness: its receipt stopped at `input_accepted` after a 2 second wait because a script never starts a turn.
  A real turn start (`turn_started`) is therefore unobserved in the lab and is taken from the CLI's own documentation.

## Capability gate

`orca status --json` lists `result.runtime.capabilities[]` (306 entries on 1.4.261) including `terminal.prompt-delivery.v1`.
That is the capability the receipt options depend on, so it is the one gate.
Reading it costs one `orca status --json` call per send, which the adapter already makes at spawn.

## Alternatives considered

- **Cache the capability list per shell.** Rejected: a runtime can be replaced by a different version under the same shell, and one status call per send is small against a wait-submit window.
- **A new `terminal-gone` verdict with exit 0.** Rejected: four other callers of `fm_backend_send_text_submit` (`bin/fm-control.sh`, `bin/fm-supervise-daemon.sh`, `bin/fm-spawn.sh` twice) test only for `send-failed` or a nonzero exit.
  A gone terminal must read as a failure to every one of them, so the adapter prints `terminal-gone` and exits nonzero, and only the ring and `fm-send` look at the word.
- **Replaying until a turn starts, with no composer read.** Rejected: a slash-command popup can swallow the Enter that the receipt send carried, and a replay never presses Enter again, so the final step keeps the existing proven-pending Enter retry.
- **Mapping a not-started receipt to `unknown`.** Rejected: `unknown` makes `fm-send` exit 1, inviting a duplicate resend of text Orca has already accepted.
  `pending` is the existing "typed, unconfirmed, do not resend" verdict.

## Real answers for a dead endpoint (Orca 1.4.261 headless, lab, 2026-11-19)

All three come back as `{"ok":false,"error":{"code":...,"message":...}}` from `terminal send --enter --wait-submit 1 --json`, and the CLI exits nonzero.

| target | `error.code` |
| --- | --- |
| a terminal the lab had closed | `terminal_not_writable` |
| a shell that had exited but was still listed | `terminal_not_writable` |
| a handle the runtime never issued | `terminal_handle_stale` |

The message of every one of them embeds a request id and the line "Re-issue the exact command with --retry-request <id> ... do not retry it without that ID", so a replay after a gone answer is possible but pointless: the endpoint will not take the input.
A plain shell answers a send with `accepted: true` and `prompt.provider = unsupported`, `prompt.observation = unsupported`, with the warning "input was accepted, but this provider cannot report delivery".

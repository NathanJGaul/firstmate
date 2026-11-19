# Research: Orca Escape and Ctrl+U Delivery

## Facts used

- Orca's `terminal send --text` without `--enter` writes the text verbatim, and the lab proved ESC (`\x1b`) and Ctrl+U (`\x15`) reach a `cat -v` shell that way (`docs/verification/runtime-backends.md`, assertion 5).
- `terminal send --interrupt` is Ctrl+C and `--enter` submits, so neither may carry a control byte meant as a key.
- `orca status --json` carries `result.runtime.appVersion` and `result.runtime.capabilities` on Orca 1.4.261, a 306-entry list.
- No capability in that list names control-byte passthrough. The terminal-related ones are `terminal.ordered-input.v1`, `terminal.prompt-delivery.v1`, `terminal.program-status.v1`, `terminal.query-reply-input.v1`, `terminal.create-idempotency.v2`, `terminal.agent-id.v1`, and a few more about layout.
- Only Devin has an interrupt arm or hazard signal, so only Devin needs a viewport read between presses, which Orca lacks.
- `fm_backend_orca_runtime_check` runs once, at spawn, in `bin/fm-spawn.sh`. `bin/fm-control.sh` and `bin/fm-send.sh` are separate processes.

## Decisions

### D1: The live gate belongs to the adapter, not the key table

`fm_control_backend_supports_key` is a pure table that `docs/agent-control.md` describes as readable as a contract.
A live status read does not belong in it, and `fm-send --key` bypasses it anyway.
The adapter's `send_key` is the one point every caller reaches, so the gate sits there, and the table says only that Orca can deliver the keys.

### D2: Read the status fresh for each control byte

Caching in a variable would be stale in any long-lived caller, and the read is one cheap local call.
An interrupt makes at most two such reads.

### D3: Gate on terminal.ordered-input.v1

It is the closest marker: present on the runtime where passthrough was proven, about ordered terminal input, and not about prompts or agents.
Rejected: `terminal.prompt-delivery.v1`, which is about the `--enter` path and would claim the wrong thing; `agent-session.keyboard.v1`, which is about structured agent sessions, not raw terminals.
The proxy is stated in the code, the docs, and the spec rather than presented as Orca's own flag.

### D4: Floor at 1.4.261, absent version tolerated

The only live proof is 1.4.261, so a lower floor would claim more than is known.
An absent version proves nothing about age, so it is not refused, but it also reports no capability, so no gated feature turns on.

### D5: Recording facts in shell variables

`fm_backend_orca_status_read` sets `FM_ORCA_APP_VERSION`, `FM_ORCA_CAPABILITIES`, and `FM_ORCA_BELOW_FLOOR` rather than printing, because callers need all three and a command substitution would lose them.

### D6: No change to exit, relaunch, or the state classifier

Both wait on a recovery-grade proof that an agent stopped, which is the next slice in the plan.

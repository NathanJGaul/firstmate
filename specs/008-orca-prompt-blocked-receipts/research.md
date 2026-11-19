# Research: Orca Prompt-Blocked Receipts

Observed on Orca 1.4.261 (scout report section 4.3, LAB-261): `terminal send --text 1 --enter` to an agent parked on the Claude workspace-trust dialog returned `ok:false`, `error.code = "agent_prompt_blocked"`, with a message that says to send text and Enter as separate commands, to re-issue the exact command with `--retry-request <id>`, and not to retry without that ID.
A hook-less agent returned `stages:["input_accepted"]` plus a warning and `observation:"supported"`; with hook events the same send returned `["input_accepted","turn_started"]`.

Decision D1: the ring result for a blocked prompt is 2, not 1.
Return 1 means the composer provably holds someone else's pending text, and `fm-send` prints that reason for it; return 3 means the agent is dead.
Neither is true for a parked dialog, and 2 keeps the watcher's bounded re-ring while its message can name the cause.
The task statement asks for a failure, which is 2.

Decision D2: no blind retry.
The adapter does not follow Orca's "send separately" advice, because a text-plus-Enter into a dialog presses its default choice.
The next doorbell is a fresh send by the watcher's bounded ladder, after the dialog may have been answered.

Decision D3: the ring prints its own stderr line, because it discards the adapter's stderr by design.

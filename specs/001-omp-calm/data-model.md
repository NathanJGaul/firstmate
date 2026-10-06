# OMP Calm presentation data model

## CalmPreference

| Field | Shape | Rule |
| --- | --- | --- |
| effective path | absolute path | Resolve `FM_CONFIG_OVERRIDE`, otherwise `<FM_HOME or FM_ROOT_OVERRIDE or code root>/config`, then append `calm`. |
| stored value | text | `on` and legacy `max` mean active; `off`, missing, and unrecognized values mean inactive. |
| serialized value | text | Active writes `on\n`; inactive writes `off\n`. |

The preference is the existing cross-harness file. OMP must not create a second preference.

## OmpCalmState

| Field | Shape | Lifetime | Rule |
| --- | --- | --- | --- |
| active | boolean | factory/session | Controls presentation only. |
| agentRunActive | boolean | factory/session | True from `agent_start` until terminal `agent_end` (without `willContinue: true`) or `session_shutdown`. |
| animation | shared sprite state | factory | One instance survives hide/show within a session and resets at `session_start`. |
| timer | managed timer handle or absent | active run or pending cleanup | One timer while the working presentation is active; retain its handle until clearing succeeds before starting a replacement or completing cleanup. |
| workingMessageOwned | boolean | factory/session | Only a successful Calm working-message write grants ownership; stock restoration is skipped while this is false, and a failed reset leaves ownership set for retry. |
| pendingAgentStart | context plus session id or absent | factory/session | A next logical run waits for deferred cleanup without being discarded by presentation-only toggles; session replacement and terminal stop cancel it. |
| adapter availability | independent booleans | factory | One failed seam does not disable other seams. |

No field is persisted or appended to the transcript.

## OmpCalmAdapter

Each adapter has:

- a stable diagnostic name;
- a probe or registration function;
- a current active predicate;
- a failure path that reports the exact missing method or registration error;
- no authority to rewrite messages, prompts, provider context, or session records.

Current adapters:

- `working-message`: managed timer plus `setWorkingMessage`.
- `legacy-message`: `registerMessageRenderer` for the existing synthetic presentation custom type.
- `generic-transcript-row`: intentionally unsupported in OMP 18.6.1 because no generic row renderer exists; operational-user and assistant-working-note rows remain ordinary behind this diagnosed boundary.

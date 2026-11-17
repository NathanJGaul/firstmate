# Data Model: Per-Worker Browser Session

This feature stores nothing.
The session name is a pure function of the task id.

## Session name

| Input | Result |
| --- | --- |
| Creation-valid task id that is not `default` | The id, unchanged |
| The id `default` | No session name |
| An id that is empty, starts with a dot, contains a character outside `[A-Za-z0-9._-]`, or exceeds 64 characters | No session name |

## Relationships

- One task id yields at most one session name.
- Launch and cleanup both resolve the name through the same helper, so a launch that exported a session and a cleanup that stops it always agree.
- A session has at most one bridge process at a time, owned by chrome-devtools-axi, with its state under `~/.chrome-devtools-axi/sessions/<name>/`.

## State transitions

- Task spawned: session named, bridge not yet running.
- Worker uses the browser: the tool starts the bridge on demand.
- Task cleaned up: the stop ends the bridge and its browser; a missing bridge is a no-op.

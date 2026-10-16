# Data Model: Restore Main CI

This feature changes tests and two extension handlers; it adds no durable data.
The entities below are the shapes the fixes depend on.

## Run-start event (Pi 1.1 and newer)

| Field | User variant | Custom variant |
|-------|--------------|----------------|
| `type` | `"before_agent_start"` | `"before_agent_start"` |
| `messageType` | `"user"` | `"custom"` |
| `prompt` | present, the raw user text | absent |
| `message` | absent | the custom message that starts the run |

Rules:
Read `prompt` only when `messageType` is `"user"`.
A custom run counts as the processing request only when its message is the processing custom type and its content equals the queued processing content.
A pending wake is consumed only by a user run.

## Fake forge fault

A named value in the fake forge's `fault` file selects behavior per forge call: `latency`, `reserve`, `exhaust`, `fail-late`, `fail`, `down`, `not-found`, `hang`, `head`, `slow-wave`.
`slow-wave` delays the pull request read by 3 seconds and its review read by 6 seconds.
The shared fake clock only moves forward and is published by rename.

## Calm fixture

A scratch project directory holding copies of tracked extension modules.
Invariant: for every copied module, each module it imports by relative path is also copied.

## Parked drain

A wake-drain process that is blocked in its test-delay `sleep` child before the raw commit.
Only a parked drain may be interrupted by the interruption case.

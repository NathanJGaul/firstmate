# Convergence: Code Mode Guard Fixes

Merge readiness: ready for the delivery pipeline.

- Built: `onFailure: continue` on the three tracked PreToolUse hooks, the Code Mode rule in the persistent-cd deny text, and the four documentation updates with the dated lab evidence.
- Evidence: the cd, arm, turn-end, and subagent suites, four mutants, lint, the doc audit, and the runner coverage check.
- Risk: low. The decision logic and every verdict are unchanged; the hook field matters only to Claude 2.1.295 or later, and Code Mode is off everywhere.
- Remaining: confirm the extra hook field is ignored by a signed-in Grok and by Cursor and pi-code (indirect evidence only: they already tolerate the Claude-only `asyncRewake` field on the tracked Stop entries); the report's items C, D, and F (launch knob, dialog pre-flight, TUI-driven live test) stay open for the pilot slice.

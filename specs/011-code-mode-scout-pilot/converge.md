# Convergence: Code Mode Scout Pilot

## Status

- Built: C (the knob and launch-line splice), D (the acceptance pre-flight with a one-line skip note), and F (the opt-in live E2E and its login helper).
- Docs: `docs/configuration.md`, the spawn header, and the Claude adapter reference.
- Verified here: the new portable suite, the six launch-line suites (`fm-spawn-dispatch-profile`, `fm-worker-account`, `fm-claude-trust`, `fm-secondmate-harness`, `fm-backend-orca`, `fm-supervision-host`), ShellCheck, the documentation audience check, and the runner coverage check.

## Remaining

- Nothing for this slice.
  The live E2E ran on 2026-11-20 against Claude Code 2.1.328 and passed all three cases; the dated result is in `docs/verification/supervision.md`.
- Follow-up noted, not built: an `onFailure` audit for hooks other than the three tracked ones.

## Risk

- Low for every launch except a scout under `scouts`; the only change to other launches is the added `-u CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` token in the existing `env` prefix.
- An acceptance key renamed by a later Claude Code release would make the pre-flight read as not accepted, which fails safe: scouts launch without Code Mode and the spawn says why.

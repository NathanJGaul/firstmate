# Convergence: Code Mode Scout Pilot

## Status

- Built: C (the knob and launch-line splice), D (the acceptance pre-flight with a one-line skip note), and F (the opt-in live E2E and its login helper).
- Docs: `docs/configuration.md`, the spawn header, and the Claude adapter reference.
- Verified here: the new portable suite, the six launch-line suites (`fm-spawn-dispatch-profile`, `fm-worker-account`, `fm-claude-trust`, `fm-secondmate-harness`, `fm-backend-orca`, `fm-supervision-host`), ShellCheck, the documentation audience check, and the runner coverage check.

## Remaining

- Nothing for this slice.
  The live E2E was not run in validation: Code Mode reports unavailable in the interactive terminal on Claude Code 2.1.328 and this account.
  An earlier single hand-run reported all three cases passing but was not reproduced, so it is not relied on.
  Re-run on a machine where Code Mode is available; the command and record are in `docs/verification/supervision.md`.
- Follow-up noted, not built: an `onFailure` audit for hooks other than the three tracked ones.

## Risk

- Low for every launch except a scout under `scouts`; the only change to other launches is the added `-u CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` token in the existing `env` prefix.
- An acceptance key renamed by a later Claude Code release would make the pre-flight read as not accepted, which fails safe: scouts launch without Code Mode and the spawn says why.

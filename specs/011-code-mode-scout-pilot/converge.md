# Convergence: Code Mode Scout Pilot

## Status

- Built: C (the knob and launch-line splice), D (the acceptance pre-flight with a one-line skip note), and the offline half of F (the opt-in live E2E and its login helper).
- Docs: `docs/configuration.md`, the spawn header, and the Claude adapter reference.
- Verified here: the new portable suite, the six launch-line suites (`fm-spawn-dispatch-profile`, `fm-worker-account`, `fm-claude-trust`, `fm-secondmate-harness`, `fm-backend-orca`, `fm-supervision-host`), ShellCheck, the documentation audience check, and the runner coverage check.

## Remaining

- The live E2E has not run against a real Claude Code yet: it needs a throwaway Claude login that only a person can create, which is held for a decision (`needs-decision`, key `code-mode-pilot-login`).
  Until it runs, the live guard's assertions about the banner and the REPL call are written from the scout's lab observations and unproven in this repository.
- The dated live result belongs in `docs/verification/supervision.md` once the guard has run.

## Risk

- Low for every launch except a scout under `scouts`; the only change to other launches is the added `-u CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` token in the existing `env` prefix.
- An acceptance key renamed by a later Claude Code release would make the pre-flight read as not accepted, which fails safe: scouts launch without Code Mode and the spawn says why.

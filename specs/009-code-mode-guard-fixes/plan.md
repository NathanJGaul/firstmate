# Implementation Plan: Code Mode Guard Fixes

**Spec**: `specs/009-code-mode-guard-fixes/spec.md`

## Design

1. `.claude/settings.json`: add `"onFailure": "continue"` to the three PreToolUse command hooks.
2. `bin/fm-cd-command-policy.mjs`: extend the `persistent-cd` reason with the Code Mode rule; the decision logic is untouched.
3. `bin/fm-cd-pretool-check.sh` header and usage: no behavior change; its header already points at `docs/cd-guard.md`.
4. `tests/fm-cd-pretool-check.test.sh`: add the hook-config cases and the deny-text cases; the existing matrix stays as the proof that verdicts did not move.
5. Docs, one owner each:
   - `docs/cd-guard.md` owns the Code Mode rule and the stable reason text contract.
   - `.agents/skills/harness-adapters/references/harness/claude.md` owns the Claude Code Mode facts (version floor, dialog, hook failure semantics, resume rule, cwd wrapper), with a one-line pointer to the cd guard doc.
   - `docs/turnend-guard.md` owns the harness-integration statement about hook failure and `onFailure` for the PreToolUse seatbelts.
   - `docs/verification/supervision.md` owns the dated lab evidence.

## Files

`.claude/settings.json`, `bin/fm-cd-command-policy.mjs`, `tests/fm-cd-pretool-check.test.sh`, `docs/cd-guard.md`, `docs/turnend-guard.md`, `docs/verification/supervision.md`, `.agents/skills/harness-adapters/references/harness/claude.md`.

## Compatibility review

- Claude: the only harness that reads `onFailure`; 2.1.295 or later.
- Grok, Cursor, and pi-code also load `.claude/settings.json` and are expected to ignore a hook field they do not define; the Grok probe could not run because Grok was not signed in, and the verification record says so.
- Codex, OpenCode, Pi, omp: separate registrations, untouched.
- The guard decisions and every other harness's deny rendering are unchanged; only the prose reason grows.

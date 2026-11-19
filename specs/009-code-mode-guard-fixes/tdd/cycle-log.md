# Cycle Log: Code Mode Guard Fixes

Append only. Newest last.

## Baseline

- `tests/fm-cd-pretool-check.test.sh` -> rc=0 (125 s) and `tests/fm-turnend-guard.test.sh` -> rc=0 (68 s), run from the clean branch before any edit.
- full profile suite: not run here, left to CI.

Method notes:

- The cd suite has no per-test selector, so each red was observed by running only the named function through a scratch copy of the test file whose call list was replaced, against unchanged code; the wrapper is not committed.
- Tests, implementation, and this log land together.

## Cycle 1: the hooks stay fail-open under Code Mode (A1, A2)

- tests (new): `test_claude_pretool_hooks_continue_on_failure` (A1), `test_claude_pretool_hook_launch_failure_is_not_a_deny` (A2)
- red, A1: `not ok - every tracked PreToolUse hook must be a command hook with onFailure=continue, offenders:` followed by all three tracked commands.
- A2 is a characterization of the launch-failure shape (126 or 127, empty stdout) the field governs, so it was green before the change by design; its strength is shown by mutant M2 in `tdd/verification.md`.
- green: `"onFailure": "continue"` on the three PreToolUse command hooks; `.claude/settings.json` stays valid JSON.
- refactor: none.

## Cycle 2: the deny text teaches the Code Mode rule (A3)

- test (new): `test_deny_text_teaches_the_code_mode_rule`, over the exact command a `.cwd()` call produces and a plain `cd projects/foo`.
- red: `not ok - the deny text must name Code Mode (missing: 'Code Mode')`, the unchanged reason printed beneath.
- green: the `persistent-cd` reason in `bin/fm-cd-command-policy.mjs` ends with the Code Mode rule; the decision logic is untouched, and A4 (the full existing matrix across five entry forms) stays green.
- refactor: the first draft asserted `absolute path`, which the new sentence also contains, so mutant M4 survived; the assertion now pins the original phrase `on the command itself` and M4 is killed.

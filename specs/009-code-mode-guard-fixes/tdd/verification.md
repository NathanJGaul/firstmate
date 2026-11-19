# TDD Verification: Code Mode Guard Fixes

Verdict: PASS, with the limitations named below.

## Test-first evidence

`tdd/cycle-log.md` records the red output against the unchanged code for A1 and A3.
A2 and A4 are characterizations that were green before the change by design: A2 pins the launch-failure shape `onFailure` governs, and A4 is the existing block and allow matrix that proves no verdict moved.

## Mutation evidence

No mutation tool is installed, so deliberate mutants were applied to the working copy and the named test re-run; each file was restored afterwards.

| mutant | killed by |
| --- | --- |
| M1 one hook's `onFailure` set to `block` | `test_claude_pretool_hooks_continue_on_failure` |
| M2 a tracked hook command ends `|| exit 2`, so a launch failure reads as a deny | `test_claude_pretool_hook_launch_failure_is_not_a_deny` |
| M3 the reason loses `never pass .cwd() or a leading cd` | `test_deny_text_teaches_the_code_mode_rule` |
| M4 the reason loses the original `or an absolute path on the command itself` advice | `test_deny_text_teaches_the_code_mode_rule` (it first survived a loose assertion, which was tightened) |

## Acceptance coverage

US1 maps to A1 and A2, US2 to A3 and A4; US3 is documentation checked by `bin/fm-doc-audience-check.sh`.

## Limitations

- The behavior that a Code Mode session actually runs a call whose hook failed rests on the dated lab evidence in `docs/verification/supervision.md`; it is not re-proved here, because the installed Claude Code (2.1.316) is below the 2.1.323 floor and a TUI-driven live test is a separate follow-up (report item F).
- Grok, Cursor, and pi-code tolerance of the extra hook field is unconfirmed (Grok was not signed in).

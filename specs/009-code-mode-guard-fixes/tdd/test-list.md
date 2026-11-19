---
feature: 009-code-mode-guard-fixes
loop: outside-in
profile: .specify/memory/tdd-profile.md
---

# Test List: Code Mode Guard Fixes

| id | behavior | traces | state | test |
| -- | -------- | ------ | ----- | ---- |
| A1 | Every tracked PreToolUse hook is a command hook with `onFailure` set to `continue`, in valid JSON, three of them | US1.1, FR-001, FR-002 | DONE | `tests/fm-cd-pretool-check.test.sh::test_claude_pretool_hooks_continue_on_failure` |
| A2 | Each tracked PreToolUse command, run with its script missing or not executable, exits 126 or 127 with empty stdout, never 2 | US1.2 | DONE | `tests/fm-cd-pretool-check.test.sh::test_claude_pretool_hook_launch_failure_is_not_a_deny` |
| A3 | The `.cwd()`-shaped command is denied through every entry form and the deny text carries the Code Mode rule and the existing advice, still after `[persistent-cd]` | US2.1, US2.2, FR-003 | DONE | `tests/fm-cd-pretool-check.test.sh::test_deny_text_teaches_the_code_mode_rule` |
| A4 | The unchanged block and allow matrix still passes through every entry form | US2.3, FR-004 | DONE | `tests/fm-cd-pretool-check.test.sh::test_full_acceptance_matrix` |

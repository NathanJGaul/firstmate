# Quality Checklist: Code Mode Guard Fixes

- [X] A1 and A3 were seen failing for the right reason first; A2 and A4 are characterizations (`tdd/cycle-log.md`).
- [X] The three PreToolUse hooks carry `onFailure: continue`; no other hook and no matcher changed; the file is valid JSON.
- [X] What the guard denies and allows did not change: the five-entry-form matrix is green.
- [X] The deny text leads with `[persistent-cd]`, keeps its old advice, and adds the Code Mode rule.
- [X] No launch knob, no spawn edit, no exemption, no REPL scan.
- [X] Each fact is stated once at its owner: the rule in `docs/cd-guard.md`, hook semantics in `docs/turnend-guard.md`, adapter facts in the Claude reference, evidence in `docs/verification/supervision.md`.
- [X] `bin/fm-doc-audience-check.sh` and `bin/fm-lint.sh` (ShellCheck 0.11.0) pass; `bin/fm-test-run.sh --check-coverage` is ok.
- [X] The cd, turn-end, subagent, and arm PreToolUse suites pass.

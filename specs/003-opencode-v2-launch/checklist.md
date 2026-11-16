# Quality Checklist: OpenCode v2 Worker Launch

- [X] Every acceptance scenario has a test (`tdd/test-list.md`).
- [X] Other harness launches are untouched (diff confined to the opencode branches).
- [X] `bin/fm-lint.sh` clean under pinned ShellCheck 0.11.0; `bin/fm-doc-audience-check.sh` ok.
- [X] Opencode reference and configuration doc state the verified 2.x facts.
- [X] Live TUI check on opencode 2.2.5 recorded.
- [X] Compatibility: the generated plugin keeps the 1.x entry point.

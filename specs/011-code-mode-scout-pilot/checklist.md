# Quality Checklist: Code Mode Scout Pilot

- [x] Every functional requirement FR-001 to FR-012 is covered by a test or a doc owner (`tdd/verification.md`).
- [x] The primary is never launched with the variable: no path sets it, the engine unsets it, and the knob is not inherited.
- [x] Nothing reads or writes the captain's `~/.claude`; the portable suite uses a throwaway `HOME`, and the live E2E and its login helper refuse a real store.
- [x] The acceptance of the Code Mode confirmation is only read, never written or answered.
- [x] `docs/configuration.md` owns the knob; the spawn header and the adapter reference point at it.
- [x] Existing launch-line assertions updated for the new `-u` token; six affected suites pass.
- [x] ShellCheck 0.11.0 clean on the changed shell files; `bin/fm-doc-audience-check.sh` and `bin/fm-test-run.sh --check-coverage` pass.
- [x] Tracked Markdown is one sentence per line with plain dashes.

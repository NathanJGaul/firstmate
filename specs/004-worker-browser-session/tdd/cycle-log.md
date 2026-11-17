# Cycle Log: Per-Worker Browser Session

Append only.
Newest last.
Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Baseline

- focused: `bin/fm-test-run.sh tests/fm-spawn-compact-adviser-disable.test.sh` -> every test ok, exit 0, 78 s
- focused: `bin/fm-test-run.sh tests/fm-teardown.test.sh` -> baseline run recorded below once it finishes (long file, runs over ten minutes)
- full suite: not run locally; `bin/fm-test-run.sh --all` is a multi-hundred-script walk, and CI plus the no-mistakes pipeline own broad regression coverage for this repository
- commit: `af20b2c9`
- recorded: cycle 0, before any change

## Notes and deviations

- `.specify/memory/constitution.md` is still the unratified template, so the TDD principle is taken from `.agents/skills/spec-kit-workflow/SKILL.md`; the constitution is left untouched because changing it needs the captain's approval of its exact wording.

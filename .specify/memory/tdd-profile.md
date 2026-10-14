---
detected_at: 43bf6d3d
ecosystems: [shell]
default: shell
stacks:
  shell:
    cwd: .
    runner: bin/fm-test-run.sh
    single: 'bin/fm-test-run.sh {file}'
    file: 'bin/fm-test-run.sh {file}'
    suite: 'bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin'
    watch: null
    coverage: 'bin/fm-test-run.sh --check-coverage'
    mutation: null
    acceptance: 'bin/fm-test-run.sh {file}'
    property: null
    approval: null
    contract: null
    test_glob: 'tests/*.test.sh'
    exemplar:
      unit: tests/fm-inbox.test.sh
      acceptance: tests/fm-inbox.test.sh
    helpers:
      - tests/lib.sh
      - tests/fixtures.sh
verified: [single, file, acceptance, coverage]
suite_baseline: pending
suite_seconds: null
---

# TDD Stack Profile

## Conventions to match

- Tests are executable Bash scripts named `tests/<subject>.test.sh`.
- Tests source `tests/lib.sh` for assertions, temporary roots, fake binaries, and cleanup.
- Tests use public scripts and inspect durable records and observable output.
- No mutation or property-testing tool is installed; high-risk behavior needs deliberate-mutant checks.
- Non-OMP live adapter and Herdr tests are excluded by task instruction; OMP-only validation records this limitation.

## Notes and constraints

- The focused existing exemplar passed with `bin/fm-test-run.sh tests/fm-inbox.test.sh`.
- `bin/fm-test-run.sh --check-coverage` is the runner inventory guard.
- The full OMP-only baseline is running separately; a red baseline blocks TDD claims.

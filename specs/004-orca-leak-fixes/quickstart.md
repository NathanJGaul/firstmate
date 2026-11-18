# Quickstart: validating the Orca leak fixes

Prerequisites: a checkout of this branch, `bash`, `node`, and `git`; no Orca install is needed because the tests use a fake `orca` on the path.

1. Run the adapter tests: `bin/fm-test-run.sh tests/fm-backend-orca.test.sh`.
   Expect every case to print `ok`, including the startup-terminal, `terminal`, neither, `spawned:false`, and path-missing cases, and the release-argument cases.
2. Run the neighbouring suites that exercise the same release: `bin/fm-test-run.sh tests/fm-teardown-endpoint-safety.test.sh`.
3. Lint: `bin/fm-lint.sh` and `bin/fm-doc-audience-check.sh`.

What this proves: firstmate's side only.
Live proof, one live terminal after a real Orca spawn and the Orca-made branch gone after a landed ship and kept after an unlanded one, needs the Linux Orca lab from a later slice.

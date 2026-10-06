# OMP Calm presentation quickstart

## Prerequisites

- OMP is installed and reports its version with `omp --version`.
- The working directory is this Firstmate repository.
- `FM_HOME` points to an isolated test home when checking persistence.
- No model turn is required for the portable extension contract checks.

## Focused behavior checks

```sh
bin/fm-test-run.sh tests/fm-calm-omp-extension.test.sh
bin/fm-test-run.sh tests/fm-calm-claude-mod.test.sh
bin/fm-test-run.sh tests/fm-calm-pi-extension.test.sh
```

Expected result: the OMP and Claude selected scripts report zero failures. The Pi script is the cross-harness regression and must also be green when its installed Pi package and current export renderer are available; any baseline limitation is recorded in `docs/verification/runtime-backends.md`. The OMP test exercises `/calm` preference toggling, lifecycle timer cleanup, the shared sprite projection, native-tool delegation, adapter diagnostics, and the preservation boundary through the extension's public registration contract.

## Maintainer smoke check

```sh
omp --version
FM_HOME="$(mktemp -d)" omp --cwd "$PWD" --no-session --no-tools -p "exit without tools"
```

The maintainer verification record owns the exact observed output and any credential or provider limitation. The smoke check is not a substitute for the portable test because it intentionally does not require a model turn.

## OMP UI check

Start OMP from an isolated home with the repository extension auto-discovered, run `/calm`, start a real model turn, resize the terminal, and run `/calm` again. Verify that the working row returns to OMP's default message after the run and that the existing session/export still contains the original user and assistant content. Record the current OMP version and command output in `docs/verification/runtime-backends.md` rather than in this feature guide.

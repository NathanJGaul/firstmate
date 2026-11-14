# Research: Local CI Merge Evidence

**Feature**: `003-local-ci-merge-evidence` | **Date**: 2026-10-26

## Sources consulted

- `data/pricing-sheet-local-ci/report.md` (private home state): the option C design, the nine check names a pricing-sheet workflow reports, and the finding that the per-name waivers cannot cover nine names.
- `bin/fm-pr-merge.sh`: the existing `--allow-red`/`--allow-missing` parsing, the away-refusal path, and the two check loops inside `github_verify_mergeable`.
- `data/pricing-sheet-local-ci/local-ci.sh` (private home state): its `ORDER`/`NAMES` arrays, its per-job `results/<stem>` records, and its summary loop.
- `tests/fm-pr-merge.test.sh`: the `make_case`, `add_gh_mocks`, `write_github_live_json`, and `run_pr_merge` helpers, which let a case drive every refusal without a network.

## Decisions

### D1 - One flag, one file, name-exact coverage

The evidence file waives a check only by exact job-name equality, which is the same matching rule `--allow-red` uses.
Rejected alternative: a boolean "trust local CI" flag.
It would waive names no local job ever covered, which is exactly the hole the report warns about.

### D2 - A head mismatch refuses rather than degrading

Rejected alternative: treat a mismatched file as "grants nothing" and let the merge proceed if the hosted checks happen to be green.
A caller who passed the flag asked for a local-proof merge; silently merging on hosted green hides that the proof was stale, and the operator would believe local evidence carried the merge.

### D3 - Absent coverage keeps the existing refusal and adds one line naming it

The refusal for an uncovered check must stay the existing "check is not green" / "required check has not reported" message, because those statements remain true and other tooling reads them.
The feature adds one summary line naming which checks the file does not cover, so the operator learns the file, not the forge, was short.

### D4 - No forge writes

Rejected alternative: publish local results as commit statuses (option B of the report).
The captain chose C explicitly, and a status written by the local machine is a claim about a hosted run that did not happen.
The tests assert that no `api` write call and no status POST appears in the recorded forge invocations.

### D5 - The runner file stays outside this repository

The runner is private home state and the brief authorizes editing exactly that one file.
The repository therefore tests the consuming side from fixtures, and tests the emission logic through a fixture-level harness that mirrors the runner's own summary loop rather than invoking a real project build.
Documented as a baseline limitation in `tdd/verification.md`.

### D6 - Refusal exit statuses follow existing convention

Usage and input-shape errors exit 2, exactly as the existing argument errors do; evidence refusals exit 1 like every other merge refusal.
A test pins each one.

## Open questions

None blocking.
Whether the runner should also gain a `--parallel` mode, an automatic shard rerun, or a `webServer.timeout` env passthrough is follow-up work recorded in `converge.md`, not part of this feature.

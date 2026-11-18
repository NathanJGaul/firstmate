# Claim Audit Contract: Orca Documentation Truth Pass

This feature exposes no product interface.
The contract below is the observable check on the prose, run as `tdd/claim-audit.sh`, committed as feature evidence and not registered as a repository test.

## C1 - Stale claims absent

Input: the five touched files.
Output: none of the six stale statements matches.
The audit greps for these shapes: the Orca backend described as macOS-only or "experimental macOS"; "no stable CLI version"; "no native Orca busy signal"; "Escape is not" and "Escape is unsupported" as an Orca-wide limit; "Orca's terminal API exposes only an interrupt and an Enter"; "Orca's worktree shape is unverified" and "Orca's worktree shape is UNVERIFIED"; "reuses only the verified `result.terminal.handle`"; "Open the Orca app to watch".
Entry point: `tdd/claim-audit.sh`, red on the baseline and green after the edits.

## C2 - Required claims present

Input: the five touched files.
Output: each required statement matches in its owning file.
Required: Linux and headless in the Orca backend document; a version and capability statement; native agent state not used; Enter and Ctrl+C delivered and Escape and Ctrl+U not; linked worktrees; startup terminal; the three captain decisions; interrupt, exit, and relaunch refuse in the recovery skill; a Linux headless 1.4.261 entry and a retained macOS 1.4.116 entry in the verification record.
Entry point: the audit script.

## C3 - Script change is comment-only

Input: `git diff` of `bin/fm-claude-trust.sh` against the base commit.
Output: every added or removed line is a comment line or blank.
Entry point: a diff filter run in the audit script.

## C4 - Existing suites unchanged and green

Input: the repository at the end of the change.
Output: `bin/fm-doc-audience-check.sh`, `tests/fm-documentation-audiences.test.sh`, `tests/fm-claude-trust.test.sh`, `tests/fm-backend-orca.test.sh`, `tests/fm-control.test.sh`, `tests/fm-backend.test.sh`, and `bin/fm-lint.sh` all pass with no test file modified.

## C5 - Style

Input: every changed Markdown line.
Output: one sentence per line, no em dash, no agent co-author in any commit.

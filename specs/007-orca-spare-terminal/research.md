# Research: Orca Spare Terminal

## R1 - The real command and its response shape

- Decision: use `orca terminal list --worktree id:<worktree id> --json` and read `result.terminals[]`.
- Evidence: observed live on 2026-11-19 in the isolated lab (Orca 1.4.261, Linux headless), immediately after `worktree create --no-parent --setup skip`.
  The response was `{"ok":true,"result":{"terminals":[{"handle":"term_...","worktreeId":"<repo-id>::<path>","worktreePath":"<path>","orphaned":false,"connected":true,"writable":true,"title":"...","preview":"...","tabId":"...","leafId":"...","ptyId":"...","executionHostId":"local"}],"hostScope":{...},"topologyRevisions":{...},"totalCount":1,"truncated":false}}`.
- The worktree creation response on the same runtime has keys `catalogVersion, lineage, warnings, workspaceLineage, worktree` and no terminal of either shape.

## R2 - Timing

- Decision: read the list once, with no retry or delay.
- Evidence: three live runs polled the list immediately after create and the first poll already reported one terminal.
- Alternatives: a bounded retry, rejected because it adds latency to every genuine no-terminal spawn and a race only degrades to the old create fallback.

## R3 - Which listed terminal to adopt

- Decision: the first row with a non-empty string handle, not orphaned, not `writable:false`, and, when it carries `worktreeId`, equal to the created worktree's id.
- Alternatives: require exactly one row, rejected because it would create a spare terminal whenever Orca lists extra ones; adopt every listed terminal, rejected because teardown records and closes exactly one.

## R4 - Failure handling

- Decision: a list that exits non-zero, reports `ok:false`, or is not parseable is treated as "no terminal found", so the old create fallback runs and the spawn never fails because of the list.

## R5 - Test fake

- Decision: teach the shared fake Orca a keyed answer for `terminal list` that does not consume the numbered response sequence, defaulting to an empty list.
- Rationale: every existing numbered response keeps its meaning, so existing cases change only where they assert the exact call log.

# Quality Checklist: Orca Branch At Create

- [X] Every behavior test was seen failing for the right reason before its implementation (`tdd/cycle-log.md`).
- [X] A fresh Orca ship is created on `<prefix><id>`, and the worktree, the task record, and the brief agree on the branch (A1, A5, A6, lab step F).
- [X] A branch Orca renames, or a runtime that ignores the flag, is refused and the new worktree released (A4).
- [X] The base branch reaches the create as `origin/<base>` after a fetch, and a base origin cannot supply is refused before anything is created (A2, A9, lab).
- [X] A scout, a secondmate, and a relaunch name no branch (A3, plan D2).
- [X] The ship brief's first action works at a detached HEAD and on the branch, and `fm_brief_base_branches` still reads the base line (A5, A6).
- [X] The Orca arm of teardown never detaches or runs `git branch -D`, even forced; the branch is deleted only by `worktree rm --force --delete-branch` (A7, lab).
- [X] The call without a branch is byte-identical to before (U2).
- [X] No other backend, launch path, control verb, or capability gate was touched.
- [X] `bin/fm-lint.sh` passes with ShellCheck 0.11.0 and actionlint 1.7.12; `bin/fm-doc-audience-check.sh` passes.
- [X] `docs/orca-backend.md` and `docs/verification/runtime-backends.md` are updated.
- [X] The live lab ran only in its isolated runtime with the launcher's pinned `HOME` and left nothing behind (its final inventory assertion held).

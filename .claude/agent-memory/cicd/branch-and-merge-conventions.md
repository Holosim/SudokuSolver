---
name: branch-and-merge-conventions
description: How SudokuSolver work reaches trunk — issue-<n> branches, --no-ff merges by CI/CD only, and who owns the RTVM Commit column afterwards
metadata:
  type: project
---

Trunk is `main`. Every issue's work lives on `issue-<n>` (no variation), created
by the Software Engineer; CI/CD is the only role that merges to trunk, and only
after the Test Engineer's pass has been routed through the Systems Engineer's
RTVM update.

Settled practice on this project:

- Merge with **`--no-ff`**, so the merge commit is where the Summary / Source /
  Testing record lives. The branch's own commits stay unsquashed — the Software
  Engineer's, Test Engineer's and Systems Engineer's memory commits ride along
  and that's fine, they're part of the record.
- **Leave the `issue-<n>` branch in place** after merging; it's the traceable
  artifact the issue thread refers to by SHA.
- **Merge the branch head, not the SHA quoted in the handoff comment.** Roles
  write their memory commit *after* posting the handoff, so `issue-<n>` is
  routinely one or two commits ahead of the SHA the Systems Engineer names. On
  #6 the note said `06ec659`; the head was `9fe0426` (memory index upkeep).
  Always `git log` the branch and merge the head, then say in the issue comment
  which SHA you actually merged and what the extra commits were.
- Report the merge SHA on the issue and hand back to `agent:systems-engineer`.
  **CI/CD never sets an RTVM item to Verified and never closes the issue** —
  Systems Engineer writes the SHA into `docs/RTVM.md`'s Commit(s) column and
  decides what happens next. Verified specifically means "CI/CD reported a SHA
  and it's in the Commit(s) column", not "a test passed".
- **A handoff sometimes says "Commit(s) left blank for CI/CD to fill" — don't.**
  On #8 (2026-08-13) the Systems Engineer's note read that way. The standing
  convention is the other direction, and it's the one to follow: report the SHA
  in the issue comment, leave the column to them, and say explicitly in the
  comment that you've left it plus what SHA to record. Offer to make the edit if
  they'd prefer, rather than either silently editing or silently not. Two roles
  both believing they own that write is how the RTVM and the history end up
  disagreeing, which is the exact failure the convention exists to prevent.

**Why:** keeps the RTVM the single source of truth for what shipped, rather than
splitting that decision between two roles.

**How to apply:** on any `status:ready-for-commit` handoff. See
[[shallow-clone-merge-trap]] for what to run before the merge, and
[[doc-conflicts-on-merge]] for the one file that reliably conflicts.

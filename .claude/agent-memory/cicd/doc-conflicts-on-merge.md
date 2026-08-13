---
name: doc-conflicts-on-merge
description: Shared docs get edited on trunk while a branch is open — resolve per-hunk, never whole-file, and treat the Systems Engineer's "take branch X" note as scoped to the branch it compared against, not to trunk
metadata:
  type: project
---

`docs/RTVM.md` and `docs/SDD.md` are edited by the Systems Engineer on *both*
trunk and open issue branches, so they're the files that conflict at merge time.
On #5, trunk's `docs/RTVM.md` §9 had been rewritten as a strict superset of the
branch's §9 while the branch also carried DELIV status changes elsewhere in the
same file.

Resolution rule:

- Look on the issue and on the escalation issue for a **merge note from the
  Systems Engineer** saying which side wins — on #5 it was "take `main`'s §9",
  stated in advance on both #5 and #23.
- Resolve **hunk by hunk**, keeping the named side only inside the conflict
  markers. `git checkout --ours <file>` would have thrown away the branch's
  auto-merged status-column edits elsewhere in the file, silently.
- **A "take branch X's version, it's a strict superset" note is scoped to the
  branch it was written against — re-check it against trunk yourself.** On #7
  (2026-08-13) the Systems Engineer said to take `issue-7`'s `docs/RTVM.md`
  because it was a superset of `issue-6`'s *pending* version. True — but
  `issue-6` had since merged, and trunk had gained `d07b853`, which wrote merge
  SHA `3bc1b22` into the Commit(s) column for RTVM-100/101/106 and added the
  §9.5 merge/regression note. Taking `issue-7` wholesale would have silently
  reverted the SHA recording the whole process exists to produce. The note was
  written before that trunk commit existed; it wasn't wrong, it was stale.
- Run `git log --oneline <merge-base>..origin/main -- docs/RTVM.md docs/SDD.md`
  **before** merging. If trunk touched the docs at all, no blanket side-rule
  survives and every hunk gets read.
- Verify afterwards by diffing against **both parents**, not just one:
  `git diff main:docs/RTVM.md docs/RTVM.md` should show only the branch's
  intended additions, and `git diff origin/issue-<n>:docs/RTVM.md docs/RTVM.md`
  only trunk's. One diff can look perfect while the other side is gone.
- Record the resolution in the merge commit message so it isn't reverse-
  engineered later.

**Why:** whole-file conflict resolution on a document several roles write to
loses work that merged cleanly, and the loss is invisible in the diff you're
looking at. The Commit(s) column is the highest-value thing in the file and the
easiest to lose this way, because the branch legitimately has no reason to
contain it.

**How to apply:** any merge touching `docs/`. Also check `.claude/locks/` is
empty before editing a lockable doc yourself (`docs/LOCKING.md`).
Related: [[branch-and-merge-conventions]].

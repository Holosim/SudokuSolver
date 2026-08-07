---
name: doc-conflicts-on-merge
description: Shared docs get edited on trunk while a branch is open — resolve per-hunk, never whole-file, and check the Systems Engineer's merge note first
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
- Verify afterwards with `git diff main:docs/RTVM.md docs/RTVM.md` — the only
  differences should be the branch's intended changes.
- Record the resolution in the merge commit message so it isn't reverse-
  engineered later.

**Why:** whole-file conflict resolution on a document several roles write to
loses work that merged cleanly, and the loss is invisible in the diff you're
looking at.

**How to apply:** any merge touching `docs/`. Also check `.claude/locks/` is
empty before editing a lockable doc yourself (`docs/LOCKING.md`).
Related: [[branch-and-merge-conventions]].

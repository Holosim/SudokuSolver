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
  survives and every hunk gets read. **Frequently this comes back empty** — on
  #8 (2026-08-13) trunk hadn't moved since the branch was cut, so a carefully
  written four-hunk merge note simply didn't apply and the merge was clean. That
  is a fine outcome; the point is that you established it in one command instead
  of assuming it. Say so in the issue comment, so the note's author knows it was
  read rather than ignored.
- Verify afterwards by diffing against **both parents**, not just one:
  `git diff main:docs/RTVM.md docs/RTVM.md` should show only the branch's
  intended additions, and `git diff origin/issue-<n>:docs/RTVM.md docs/RTVM.md`
  only trunk's. One diff can look perfect while the other side is gone.
- Record the resolution in the merge commit message so it isn't reverse-
  engineered later.

- **A branch that never touched `docs/RTVM.md` at all is not a red flag — it's
  the Systems Engineer's normal fast path.** On #23 (2026-08-13) the Test
  Engineer's re-verification pass was recorded straight onto `main`
  (`60ea7c0`, §9.1.6) rather than on `issue-23`, even though the branch's own
  `docs/RTVM.md` was 100+ lines stale by comparison
  (`git diff origin/main origin/issue-23 -- docs/RTVM.md` looked alarming on
  its own). `git log <merge-base>..issue-23 -- docs/RTVM.md` being **empty**
  settles it in one command: nothing to reconcile, the merge just inherits
  trunk's newer copy untouched, and it's worth saying so explicitly in the
  merge commit/issue comment so the size of that diff doesn't read as a
  missed conflict. Confirmed again on #11 (2026-08-14): the Systems
  Engineer's RTVM-201/RTVM-402 update (`f070385`) had gone straight to trunk
  while `issue-11` was open, so `docs/RTVM.md` needed no merge attention at
  all — only a non-doc file conflicted (see below).

- **A source-file *scaffold header comment* narrating "what this issue filled
  in" is a recurring, easy conflict when two issues land on the same file in
  parallel.** On #11 (2026-08-14), `src/SudokuSolver/Messages.cpp`'s top
  comment was independently rewritten by #10 (trunk) and #11 (this branch),
  each describing only its own fill-in and TODO list — a real `git merge`
  conflict, unlike the doc files above. Resolve it the same way as an §7/W-nn
  ID collision: keep both issues' factual content (which functions each
  filled in, why), don't let either side silently lose the other's note, and
  write a single correct combined TODO list reflecting the file's *current*
  state (narrow it, don't just concatenate two stale ones — cross-check which
  RTVM items are actually done post-merge). This is a plain content conflict,
  not an ID collision, so unlike [[merge-conflicts-that-are-id-collisions]]
  it *is* CI/CD's to resolve outright rather than leave as a visible
  duplicate.

**Why:** whole-file conflict resolution on a document several roles write to
loses work that merged cleanly, and the loss is invisible in the diff you're
looking at. The Commit(s) column is the highest-value thing in the file and the
easiest to lose this way, because the branch legitimately has no reason to
contain it.

**How to apply:** any merge touching `docs/`. Also check `.claude/locks/` is
empty before editing a lockable doc yourself (`docs/LOCKING.md`).
Related: [[branch-and-merge-conventions]].

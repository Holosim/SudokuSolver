---
name: merge-conflicts-that-are-id-collisions
description: When two branches each append a new numbered row (RTVM §7 I-nn, W-nn) the conflict is an ID collision, not a content clash — merge as a union, never renumber, and hand the numbering to the Systems Engineer
metadata:
  type: project
---

`docs/RTVM.md` §7 (interpretations `I-nn`), §9.1.3 (`W-nn`) and the requirement
table are **append-numbered**. Two issues in flight will each append a row and
each pick the same next number. Git reports a content conflict; what it actually
is, is two disjoint additions at the same insertion point wearing the same ID.

Resolve it as a **union**: keep every row from both sides, verbatim, trunk's
first, and delete only the three marker lines. Then **stop** — do not renumber.

**Why not renumber:** the ID is referenced from elsewhere in `docs/RTVM.md`
(§9.x ledgers), from `docs/SDD.md`, from issue comments and from source comments.
Picking which of the two collided rows gets moved, and rewriting its
cross-references, is requirements authorship. CI/CD choosing it silently is
exactly the "two roles both believe they own that write" failure that
[[branch-and-merge-conventions]] exists to prevent. Leaving a visible duplicate
is the honest state: it is obvious to the next reader, it loses nothing, and the
Systems Engineer is the very next role on the issue and is already editing the
file to write the Commit(s) SHA.

**How to apply:**
- Say in the merge commit body *and* the issue comment that the duplicate is
  deliberate, which two rows collided, where each came from, and that
  renumbering is theirs.
- Verify the union against **both parents** afterwards — `git diff <parent>`
  should show, in each direction, only the other side's additions. Any `-` line
  that is not superseded text (a status column changing `Approved` → `In Test`,
  an amended interpretation) means content was dropped.
- Grep the merged file for a marker of each side's contribution before pushing.
  On #9: `win25-vs2026` and `W-9` for trunk, `readLineBlocking` and
  `9.8 UI and OUT coverage` for the branch, plus a count of the `Commit(s)`
  SHAs — 26 of them, and they only exist on the trunk side.

**Why (incident):** on #9 (2026-08-13) trunk's `f58c868` added an `I-17` about
what "VS 2022" constrains, while `issue-9` added its own `I-17` (blocking reads
during acquisition) and `I-18`. Both were correct and neither was a mistake.

**The pattern isn't limited to `I-nn`/`W-nn` rows — §9.x subsection numbers
collide the same way.** On #13 (2026-08-14), trunk's #12 merge-record and
`issue-13`'s RTVM-507 write-up both landed as "### 9.16" (each branch's own
next-free number at the point it was cut). Same resolution: union, trunk's
section first, an explicit note in the later section flagging the duplicate
number as the Systems Engineer's to renumber — do not renumber it yourself
just because it's a heading rather than a table row.

Related: [[doc-conflicts-on-merge]], [[lock-before-merging-docs]].

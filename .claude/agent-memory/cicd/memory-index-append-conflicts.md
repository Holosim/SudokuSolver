---
name: memory-index-append-conflicts
description: "#22 — role MEMORY.md index files (not just docs/RTVM.md) conflict the same append-only way when trunk and a branch both add a new bullet after the same line; resolve as a union, same as [[merge-conflicts-that-are-id-collisions]]"
metadata:
  type: project
---

On #22 (RTVM-901/904/905/907, 2026-08-15), merging `issue-22` into `main`
conflicted in two files that are neither `docs/RTVM.md` nor `docs/SDD.md`:
`.claude/agent-memory/software-engineer/MEMORY.md` and
`.claude/agent-memory/test-engineer/MEMORY.md`. Both are pure append-only
index files (one bullet per memory entry). Trunk had gained a new bullet
(RTVM-505, from #20) after the shared "RTVM-405/406" line, and `issue-22`
had independently appended its own new bullet (RTVM-904 / RTVM-901-904-
905-907) after that same line. Git can't 3-way-merge two insertions at the
same point, so it conflicts even though neither side's content actually
overlaps.

**How to apply:** don't assume [[doc-conflicts-on-merge]] only applies to
the two Systems-Engineer-owned docs. Any role's `MEMORY.md` index (or any
other flat append-only list file) hits the same shape whenever trunk
gained an entry from one issue while a branch independently gained a
different entry from another. Resolve it exactly like
[[merge-conflicts-that-are-id-collisions]]: keep both lines, in order,
never pick one side. `grep -n` for `<<<<<<<` after `git merge --no-ff
--no-commit` to catch these — they don't show up in a `--stat` summary
the way a content rewrite would, and the file names alone (a memory
index, not RTVM/SDD) can make them easy to overlook or misdiagnose as
something needing a judgment call rather than a mechanical union.

**Why:** these files are themselves append-only by convention (one line
per memory file), so a union is always correct here — there's no
"which side is right" question the way there can be in `docs/RTVM.md`'s
Commit(s) column.

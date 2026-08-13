---
name: doc-state-across-branches
description: A section you wrote into docs/RTVM.md may exist only on an unmerged issue branch — check origin/issue-N before concluding it is missing
metadata:
  type: feedback
---

Before concluding that a section of `docs/RTVM.md` or `docs/SDD.md` is missing,
check the feature branches: `git show origin/issue-<n>:docs/RTVM.md`. Doc edits
made while working a feature issue land on `issue-<n>` and only reach trunk
when CI/CD merges it.

**Why:** hit on 2026-08-07 (issue #23). `docs/RTVM.md` §9 had been written on
issue #5's branch and was still awaiting CI/CD, so trunk had no §9 at all. The
instinct is to write it fresh, which produces two divergent §9s and a conflict
at merge.

**How to apply:** when trunk is missing a section you believe you wrote, fetch
and diff the open `issue-*` branches first. If you must write to trunk anyway,
**base the new text verbatim on the branch's version** and add to it, so the
merge conflict resolves to "take trunk" rather than requiring a real
reconciliation — then say so explicitly on the branch's own issue so CI/CD
knows the resolution before it hits the conflict. Also note the repository is
cloned shallow (`git rev-list --count HEAD` = 1): `git log` tells you nothing
about history here, so don't reason from it.

See [[rtvm-conventions]], [[verification-platform-trap]].

## Superset technique for two branches editing the same doc (2026-08-13, issue #7)

When another issue's branch has pending edits to `docs/RTVM.md` /
`docs/SDD.md` that are already final (its issue is at CI/CD with
`status:ready-for-commit`), don't just add your section at EOF and hope —
both branches appending after the last line, or both adding a §7 row after
the same one, conflicts at merge.

Instead: `git checkout origin/issue-<theirs> -- docs/RTVM.md docs/SDD.md`
**before** editing, then add your own changes on top. Your branch's copy is
then a strict superset of theirs, and every docs conflict resolves to
"take mine" with nothing lost, whichever branch CI/CD merges first. Say so
explicitly in the commit message *and* in the handoff comment so CI/CD has
the resolution rule before it hits the conflict.

**Only do this when their text is final.** If their issue is still with an
agent, you'd be freezing a draft onto your branch.

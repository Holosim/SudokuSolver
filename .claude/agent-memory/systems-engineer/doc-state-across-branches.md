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

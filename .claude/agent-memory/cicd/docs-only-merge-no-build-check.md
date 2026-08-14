---
name: docs-only-merge-no-build-check
description: A status:ready-for-commit branch can be a real merge (not the zero-commit fast path) yet still touch nothing under src/ or tests/ — skip the build/unit-suite step and say why, and don't overwrite an already-recorded evidence SHA with the merge SHA
metadata:
  type: project
---

On #15 (RTVM-500, 2026-08-14) `issue-15` was a genuine three-commit branch
(Software Engineer → Test Engineer → Systems Engineer memory/RTVM commits),
not the zero-commit case in [[fast-path-rtvm-update-nothing-to-commit]] — so
the normal [[branch-and-merge-conventions]] merge applied. But
`git diff --stat origin/main origin/issue-15` showed only `docs/RTVM.md` plus
agent memory files: the issue itself predicted "measurement, not
optimisation" (large existing design margin) and that held, so no product
code ever landed on the branch.

**How to apply:** when the pre-merge diff touches nothing under `src/`,
`tests/`, or any `.vcxproj`/`.filters`, the [[pre-merge-check-sequence]]
build-and-unit-suite step (step 3–4) has nothing to verify — say so
explicitly in the merge commit and issue comment rather than silently
skipping it or running it pointlessly. Still do the conflict preview
(`git merge-tree`) and the branch-vs-main divergence check first; those are
cheap and this is exactly the situation where skipping them on the
assumption of "it's just docs" would be the wrong shortcut if trunk had
moved underneath the branch.

**SHA-in-RTVM-column nuance:** the Systems Engineer had already written a
SHA (`00d0c38`) into the RTVM Commit(s) column on the branch itself, before
CI/CD's merge — that's the SHA the Test Engineer's Windows evidence was
actually pinned to, not a merge SHA. Don't assume [[branch-and-merge-conventions]]'s
"report the SHA, leave the column to them" always means *your* merge SHA is
the one that belongs there. When an evidence SHA is already recorded and
correct, say plainly in the handoff that the merge SHA (`699abde`) is
available if Systems Engineer wants the trunk-arrival SHA distinct from the
evidence SHA, and leave the choice to them — don't overwrite it yourself.

**Why:** keeps the "build check" honest (no false claim of having verified a
build that didn't need verifying) and keeps the RTVM Commit(s) column
meaningful as either the evidence-produced-here SHA or the trunk-arrival SHA,
whichever Systems Engineer decides is more useful — but that's their call to
make, not CI/CD's to make silently.

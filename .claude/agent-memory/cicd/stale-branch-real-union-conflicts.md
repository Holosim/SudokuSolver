---
name: stale-branch-real-union-conflicts
description: A branch cut before several other issues merged (issue-12, open since before #10/#11/#14/#15 landed) produces real, resolvable conflicts on shared files — additive on both sides, resolved as a union, not a pick-one-side
metadata:
  type: project
---

On #12 (2026-08-14), `issue-12` had been sitting `status:on-hold`/dependency-
blocked long enough that four other issues (#10, #11, #14, #15) merged to
`main` before it was released to the Software Engineer. By the time it
reached CI/CD, `git diff --stat origin/main origin/issue-12` was a ~2300-line
diff in both directions — alarming-looking, but `git merge-tree` narrowed it
to exactly four real conflicts (confirmed by `git merge --no-ff --no-commit`
directly, per [[cwd-and-merge-tree-reading-gotchas]]): a memory index
(software-engineer `MEMORY.md`), a scaffold header comment
(`Messages.cpp`, same failure mode as [[doc-conflicts-on-merge]]'s
`Messages.cpp` note from #11, now a third occurrence), a test file
(`SolverTests.cpp`, two issues' `TEST_METHOD`s landing in the same class),
and a fixture file (`TestFixtures.h`, two issues' fixture constants in the
same block). Every one of the four was **additive on both sides** — nothing
to pick, everything to keep — so each was resolved as a literal union:
concatenate both sides' content in a sensible order, don't let `git
checkout --ours/--theirs` throw either side away.

Verified the union was complete and lossless with the two-parent diff check
from [[doc-conflicts-on-merge]] (`git diff origin/main:<file> <file>` should
show only the branch's intended additions; `git diff origin/issue-12:<file>
<file>` should show only trunk's) on all four files — confirmed clean both
ways.

`docs/RTVM.md` itself needed no merge attention at all: `issue-12` never
touched it (the Systems Engineer's promotion, commit `8470fd3`, went straight
to trunk while the branch was still open — the now-familiar fast path from
[[doc-conflicts-on-merge]]), so the merged file is byte-identical to
`origin/main`, confirmed with a diff.

**Why:** a large diffstat between a branch and current trunk is not itself
evidence of a hard merge — it's just proof trunk moved a lot. The number of
*real* conflicts is almost always far smaller, and only `merge-tree`/an
actual `git merge` attempt tells you which.

**How to apply:** don't be discouraged by branch age or diff size alone;
run the real conflict-preview sequence regardless, and treat any
"scaffold header comment" or "shared test/fixture file" conflict as a
union-resolution job, not a which-side-wins judgement call.

Related: [[doc-conflicts-on-merge]], [[pre-merge-check-sequence]],
[[checkout-b-keeps-dirty-worktree]].

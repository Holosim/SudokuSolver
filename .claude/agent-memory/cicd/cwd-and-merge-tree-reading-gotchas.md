---
name: cwd-and-merge-tree-reading-gotchas
description: Two things that cost time on #11 — the Bash tool's cwd is not guaranteed to be the repo root, and merge-tree's "changed in both" header does not by itself mean a real conflict
metadata:
  type: project
---

**Bash tool cwd.** On #11 (2026-08-14) the shell's working directory at the
start of the run was already inside `.claude/agent-memory/cicd/`, not the repo
root — nothing in the transcript `cd`'d there. Path-filtered git commands
(`git log -- docs/RTVM.md`) silently returned empty from that cwd instead of
erroring, which looked like "trunk never touched the docs" when it actually
had. Always `cd "$(git rev-parse --show-toplevel)"` (or an explicit absolute
`cd` to the repo root) as the first command of any run before trusting a
path-filtered git command's *absence* of output.

**`git merge-tree <base> main issue-<n>` "changed in both" is not "conflict."**
Its legacy-format output labels a file "changed in both" whenever the blob
differs from base on both sides, whether or not the three-way merge actually
produced `<<<<<<<` markers — plenty of those sections auto-resolve cleanly
(adjacent, non-overlapping hunks). The only reliable signal of a real conflict
in that output is literal conflict markers inside the shown diff. Don't
hand-resolve a section that doesn't have them — it isn't broken. To know for
certain, just do the real merge on a scratch branch
(`git merge --no-ff --no-commit issue-<n>`) and read `git status`: unmerged
paths are the true conflict list, usually a strict subset of what
`merge-tree`'s section headers suggested. On #11, `merge-tree` showed five
"changed in both" / "merged" sections but only one (`Messages.cpp`) was an
actual `git merge` conflict.

**Local `main` looking reverted right after a push is not a revert.** After
`git push origin premerge:main`, checking out the *local* `main` branch (which
hasn't been told about the push) shows its old pre-merge tree — a diff/system
warning about a file "changing" at that point is just the checkout, not an
edit by anything external. `git merge --ff-only origin/main` (or re-fetch)
resolves it; no need to re-verify content that was already verified on the
merge commit.

**`merge-tree`'s full-diff output can be huge and still be conflict-free.** On
#17 (2026-08-15) a nine-file branch produced 54.8KB of `merge-tree` output —
every hunk of every changed file gets printed under "merged"/"our"/"their"
headers, not just the disputed ones. Don't eyeball it; pipe to a file and
`grep -c '^<<<<<<<'` — zero means clean regardless of how large or alarming
the raw output looks.

**A revert-then-redo pair already sitting in `main`'s history is not a merge
problem to solve.** Also on #17: `git log --oneline origin/main` showed the
Systems Engineer had pushed an RTVM promotion commit straight to `main`, then
reverted it one commit later, then (correctly, per
[[branch-and-merge-conventions]] for a branch carrying real `src/` changes)
redone the same promotion on `issue-17` itself for CI/CD to merge normally.
`git merge-base --is-ancestor origin/main origin/issue-17` confirmed `main`'s
tip was a clean ancestor of the branch either way, so the revert pair was
just historical noise already resolved by the other role — nothing to
reconcile, no note needed beyond recognizing it and moving on.

**Why:** all three looked like real problems (stale docs, a phantom conflict,
a silently reverted merge) and would have led to wasted re-diagnosis or an
unnecessary re-resolution if taken at face value.

**How to apply:** every merge run — cd to repo root first, trust `git merge
--no-ff --no-commit`'s actual conflict list over `merge-tree`'s section
headers, and fast-forward local `main` before reading its working tree as
evidence of anything.

Related: [[pre-merge-check-sequence]], [[shallow-clone-merge-trap]].

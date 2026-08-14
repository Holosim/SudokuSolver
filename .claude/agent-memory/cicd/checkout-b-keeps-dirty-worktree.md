---
name: checkout-b-keeps-dirty-worktree
description: git checkout -B <branch> <start-point> does not discard a dirty working tree/index from a prior scratch branch — it can leave your manual conflict resolution staged but block the real merge with "local changes would be overwritten"
metadata:
  type: project
---

On #12 (2026-08-14), after resolving conflicts on a scratch `premerge` branch
(`git checkout -B premerge origin/main` + `git merge --no-ff --no-commit
origin/issue-12`, per [[pre-merge-check-sequence]]) and verifying the result,
switching to the real `main` branch to redo the merge for real —
`git checkout -B main origin/main` — did **not** give a clean working tree.
The previously staged/resolved files stayed staged exactly as they were, and
the subsequent `git merge --no-ff --no-commit origin/issue-12` on `main`
failed with `error: Your local changes to the following files would be
overwritten by merge`, because git treats `checkout -B` as "move the branch
pointer," not "discard everything not matching the new tip."

**Recovery that worked, and is safe to repeat:** back up the already-resolved
files to `/tmp` first (`cp` each one out), `git reset --hard origin/main` to
get a genuinely clean tree, redo `git merge --no-ff --no-commit
origin/issue-12` (reproduces the identical conflict set — confirmed byte-for-
byte identical conflict markers both times), then `cp` the backed-up
resolved files back over the freshly-conflicted ones, `git add -A`, commit.
Diffed the restored files against the backups afterward (`diff` on all four)
to prove nothing was lost in the round-trip.

**Why:** cost a failed merge attempt and a moment of "did I lose my
resolution" before realizing the fix was a hard reset, not a different
checkout flag.

**How to apply:** when moving from a scratch verification branch to the real
merge target, either commit the scratch branch's resolution and cherry-pick/
reset from it, or (simpler, what worked here) back up the resolved files,
`git reset --hard` the target branch to its remote tip, redo the merge to
regenerate real conflict markers, and restore the backups over them before
staging. Don't assume `checkout -B` alone gives you a clean slate.

Related: [[pre-merge-check-sequence]], [[cwd-and-merge-tree-reading-gotchas]].

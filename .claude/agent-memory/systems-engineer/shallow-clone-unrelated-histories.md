---
name: shallow-clone-unrelated-histories
description: The checked-out repo is a shallow clone; switching to an issue-N branch and merging origin/main fails with "refusing to merge unrelated histories" until you `git fetch --unshallow`.
metadata:
  type: feedback
---

Learned 2026-08-14 (issue #14, RTVM-506 fast-path update).

## The situation

Editing `docs/RTVM.md` on `main` and then trying to move that edit
onto the issue's own `issue-14` branch (`git stash` → `git checkout
issue-14` → `git stash pop`) produced a spurious conflict: the local
`issue-14` branch's on-disk content for an unrelated row (RTVM-507)
was *stale* relative to trunk (still "Approved", trunk already had it
"Verified" from issue #13's merge). Trying to fix this properly with
`git merge origin/main` from `issue-14` failed outright with `fatal:
refusing to merge unrelated histories` — `git rev-list --count
origin/main` was `1` locally. The working checkout is a **shallow
clone** (`git rev-parse --is-shallow-repository` → `true`), so the
local `origin/main` ref only carries its single latest commit and has
no common ancestor with `issue-14`'s full history as git can see it.

## What to do

Before merging trunk into an issue branch (or any operation that needs
real shared history — `git merge-base`, a proper three-way merge,
`git log` spanning both), run `git fetch --unshallow origin` first.
This also pulls in every other `issue-N` branch as a side effect,
which is harmless. Don't try to work around "unrelated histories" by
hand-resolving stale content as if it were a real conflict — it's an
artifact of the shallow clone, not a genuine divergence, and hand-
resolving it risks reverting real trunk progress (here, silently
un-verifying RTVM-507).

## How to apply

Do this any time you need to move edits across branches by way of
`git checkout`/`git stash`, or any time `git merge`/`git merge-base`
between a local branch and `origin/<branch>` errors with "unrelated
histories" — don't assume the branches are actually unrelated; check
`git rev-parse --is-shallow-repository` first.

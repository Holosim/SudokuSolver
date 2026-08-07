---
name: shallow-clone-merge-trap
description: Agent runs check out a depth-1 shallow clone of main only — git merge fails with "refusing to merge unrelated histories" until you fetch the branch and unshallow
metadata:
  type: project
---

Every agent job starts from a **shallow (`depth=1`) checkout of `main` only**.
Two consequences that both look like a corrupted repository if you don't know:

1. `issue-<n>` doesn't exist locally at all — `git checkout issue-5` fails until
   `git fetch --all --prune`.
2. Even after fetching the branch, `git merge issue-<n>` aborts with
   **`fatal: refusing to merge unrelated histories`**, and `git log` shows the
   trunk tip as a parentless root commit. Nothing is wrong with the repo — the
   shared ancestor simply isn't in the local object store.

The fix, before any merge work:

```
git fetch --all --prune
git fetch --unshallow origin      # or: git rev-parse --is-shallow-repository
```

After unshallowing, `git merge-base main issue-<n>` resolves normally and the
merge is an ordinary one.

**Why:** cost most of a run on issue #5 (2026-08-07) diagnosing what looked
like a force-pushed orphan trunk before spotting `.git/shallow`.

**How to apply:** run the two fetches as the first thing in any run that merges
or compares branches. Never conclude history was lost until
`git rev-parse --is-shallow-repository` says `false`. Do **not** "fix" it with
`--allow-unrelated-histories` — that would fabricate a merge across two
disconnected trees and duplicate the whole repository.

Related: [[branch-and-merge-conventions]].

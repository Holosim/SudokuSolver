---
name: lock-before-merging-docs
description: A trunk merge that changes docs/RTVM.md is an edit of a lockable resource — acquire the lock first, and mind the ordering trap that lock-acquire.sh hard-resets your working branch
metadata:
  type: project
---

`docs/LOCKING.md` reads as though it is about an agent opening a file and typing
in it. **A merge counts.** If the branch changes `docs/RTVM.md` or `docs/SDD.md`,
pushing that merge rewrites a lockable document on trunk, and the failure mode is
identical: whoever holds the lock read the file before your push and may write
their copy back over it. Losing the Commit(s) column that way is the exact thing
[[doc-conflicts-on-merge]] exists to prevent.

So: check `.claude/locks/` and run `lock-acquire.sh` **before merging**, not just
before hand-editing a doc.

Ordering, which is not optional:

1. Do every pre-merge check on a **scratch branch** (`git checkout -B premerge
   origin/main` then `git merge --no-ff --no-commit origin/issue-<n>`) — see
   [[pre-merge-check-sequence]]. None of it needs the lock, and it takes minutes
   the lock holder may well finish inside.
2. **Then** acquire the lock. `lock-acquire.sh` begins each attempt with
   `git reset --hard origin/$BRANCH`, so it will silently destroy a local merge
   commit you made first. Verify on the scratch branch, acquire, re-merge on
   `main`, push, release.
3. Run it from a branch that **has an origin counterpart**. On a local-only
   branch that `reset --hard origin/<branch>` fails under `set -e` and the script
   exits non-zero — indistinguishable from "someone holds the lock", and wrong.
4. Invoke as `bash scripts/lock-acquire.sh …`; the scripts are not executable in
   a fresh checkout (`./…` gives exit 126, Permission denied).

**Backing off (exit 1, holder not stale):** comment on the issue naming the
holder, their issue number and the lock age, add `status:waiting-on-lock`, remove
`status:in-progress`, and **keep your own `agent:cicd` label**. `lock-retry.yml`
sweeps every 10 minutes and only re-triggers issues that still carry an `agent:*`
label — strip it and the issue stalls forever. This is one of the two cases where
CI/CD does not hand off to `agent:systems-engineer` at the end of a run.

Post the full pre-merge verification results in that back-off comment anyway. The
retry run is a fresh container that has to redo the work, but the thread then
shows the merge was blocked on a lock rather than on anything wrong with the
branch, and the numbers are there to compare against.

**Why:** on #9 (2026-08-13) the merge was ready and verified when
`systems-engineer` took `docs/RTVM.md` for #23, three minutes earlier, to record
the first Windows-run evidence. Both sides were writing large additions to the
same document at the same moment.

**How to apply:** every `status:ready-for-commit` run whose branch diff touches
`docs/`. Related: [[branch-and-merge-conventions]].

---
name: reset-and-redo-beats-rebase-after-push-race
description: "#18 — when a merge commit is rejected on push because main moved underneath it, `git rebase origin/main` on a --no-ff merge replays the whole branch's individual commits and reproduces every conflict from scratch; reset to origin/main and redo the merge instead"
metadata:
  type: project
---

On #18 (2026-08-15), `git push origin main` was rejected after I'd built and
committed the `--no-ff` merge of `issue-18` (`8c3d528`) — `main` had gained
one commit (`3e7406a`, an unrelated systems-engineer memory-only commit from
#20) while I worked. Reflex was `git rebase origin/main`: this was wrong.
Rebasing a merge commit doesn't replay *the merge*, it replays each of the
underlying branch commits individually onto the new base — which meant
re-hitting the exact same three conflicts (the two `MEMORY.md` append
collisions and the `docs/RTVM.md` §9.29 heading collision, see
[[merge-conflicts-that-are-id-collisions]]) one commit at a time instead of
once, for no benefit, since the new base commit didn't even touch any of the
same files.

**What worked:** `git rebase --abort`, then `git reset --hard origin/main`,
then redo `git merge --no-ff origin/issue-18` from scratch against the fresh
base. Conflicts reappeared at the *same line numbers* as before (confirming
the intervening trunk commit was genuinely orthogonal), so the same
resolutions applied cleanly. Diffed the newly-resolved files against the
first attempt's committed blobs (`git show 8c3d528:<path>` vs the working
tree) before committing again — byte-identical, confirming the redo wasn't
silently different. Second commit (`a78f0d2`) is what's actually on trunk;
the first, unpushed one doesn't exist anywhere but local reflog.

**Why:** a `--no-ff` merge commit is a single semantic unit (see
[[branch-and-merge-conventions]]); rebasing it apart into its component
commits and replaying them is strictly more conflict-resolution work than
re-running the merge once against the new tip, with no offsetting benefit
when (as here) the race is with an unrelated file.

**How to apply:** any time `git push` rejects a completed merge commit
because trunk moved. Check `git show --stat <the-new-trunk-commit>` first —
if it doesn't touch any file your merge touched, `reset --hard` + re-merge
is safe and cheap. If it *does* overlap, the same logic still holds (redo
the merge, don't rebase it), it just means the conflict set may differ from
the first attempt and needs fresh reading rather than an assumed replay.

Related: [[branch-and-merge-conventions]], [[merge-conflicts-that-are-id-collisions]], [[pre-merge-check-sequence]].

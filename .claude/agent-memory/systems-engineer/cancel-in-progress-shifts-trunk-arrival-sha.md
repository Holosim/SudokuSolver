---
name: cancel-in-progress-shifts-trunk-arrival-sha
description: When CI/CD's own required post-merge memory commit lands right after the --no-ff merge and the windows-verification workflow uses cancel-in-progress, the real regression evidence attaches to that follow-up SHA, not the merge SHA itself — record the follow-up SHA in Commit(s).
metadata:
  type: project
---

Learned 2026-08-15 (issue #19, RTVM-504).

## The situation

CI/CD merged `issue-19` `--no-ff` as `6d3d35e` (the two-parent merge
commit — confirmed via `git show -s --format=%P`, which required
`git fetch --unshallow` first since the default checkout here is
shallow, see [[shallow-clone-unrelated-histories]]). Per
[[commit-sha-recorded-is-the-merge-commit]] that's normally exactly
the SHA to record. But CI/CD's own required memory-write commit
(`292af46`, single-parent on top of `6d3d35e`) landed seconds later
and, via `windows-verification`'s `cancel-in-progress` concurrency
group, cancelled the in-flight run that had started against `6d3d35e`
in favour of a fresh run targeting `292af46`. CI/CD flagged this
explicitly in a follow-up comment rather than leaving it for me to
discover.

## How to apply

Don't reflexively record the literal `--no-ff` merge SHA the moment
CI/CD reports it — check whether CI/CD's own next commit (memory,
or anything else required by its own procedure) landed before the
regression workflow actually ran, and if the workflow uses
`cancel-in-progress`, the later SHA is where evidence will actually
attach. Confirm tree-identity between the two SHAs first (`git diff
--stat <merge> <followup> -- . ':!.claude/agent-memory'` should be
empty outside agent memory) so recording the later SHA isn't silently
picking up an unrelated change. Record the later SHA in Commit(s),
and say so explicitly in the row's §9.N narrative so a future reader
doesn't wonder why it isn't the plain merge commit.

## When the shift would still be stale by publish time (2026-08-15, #25)

At #25's commit confirmation, the same mechanism fired but the "later
SHA" (CI/CD's post-merge memory commit `0aaddb1`) was itself about to be
superseded again — by my own upcoming `docs/RTVM.md` bookkeeping push,
which also lands directly on `main`
([[commit-confirmation-pushes-direct-to-main]]) and would cancel
`0aaddb1`'s in-flight run in turn via the same `cancel-in-progress`
group. Chasing "the SHA the workflow currently targets" in that
situation just picks a different stale value. Recorded the actual `--no-ff`
merge SHA (`0892b30`) instead — it's the tree that carries the real
product/harness content — and told the Test Engineer explicitly to
regression-test whichever run is current on `main`'s tip when they look,
after confirming tree-identity to the recorded SHA for product paths.

**How to apply:** only chase the "later SHA" when it's plausibly the
*final* one before evidence is gathered (e.g. CI/CD's own single
required follow-up, nothing else queued). If your own next action is
itself another direct-to-`main` push that will retrigger
`cancel-in-progress` again, don't record an intermediate SHA that will
already be stale — record the merge SHA and shift the tree-identity
check downstream to whoever actually reads the regression result.

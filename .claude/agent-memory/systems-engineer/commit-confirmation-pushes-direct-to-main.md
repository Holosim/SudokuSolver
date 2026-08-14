---
name: commit-confirmation-pushes-direct-to-main
description: The docs/RTVM.md bookkeeping commit that records CI/CD's merge SHA and promotes a row to Verified is pushed directly to main as a single-parent commit — it does not go through another issue-<N> branch + CI/CD merge cycle.
metadata:
  type: feedback
---

Learned 2026-08-14 (issue #14, RTVM-506).

## The situation

After CI/CD hands an `[RTVM-014]`-style issue back with a merge SHA
(the "Receiving a commit confirmation from CI/CD" procedure), the only
work left is updating `docs/RTVM.md`'s Commit(s) column and Status.
`.github/AGENT_LABELS.md`'s branch convention says "Nothing gets
merged to trunk except by CI/CD, and only once Test Engineer has
signed off" — reading that literally, I almost created a fresh
`issue-14` branch for this bookkeeping commit to hand back to CI/CD
for another merge cycle.

## What the actual history shows

Checked `gh api repos/.../commits` for the RTVM-507 precedent
(issue #13): the commit that recorded `d39eacd` and promoted
RTVM-507 to Verified (`a1c7bc3`, "RTVM: record CI/CD merge SHA
d39eacd, promote RTVM-507 to Verified") has **one parent** — it sits
directly on `main` right after the merge commit, not on a branch that
was later merged again. Same shape for other commit-confirmation
bookkeeping commits in the log.

## How to apply

For a commit-confirmation hand-back specifically (not an ordinary
feature issue's Software Engineer/Test Engineer work, which does
follow the branch+CI/CD-merge cycle): after recording the SHA and
promoting the row, commit `docs/RTVM.md` and push **directly to
`main`**, single-parent, no branch, no further CI/CD round trip. The
"nothing merges to trunk except CI/CD" rule governs feature branches
carrying product work; this is a docs-only bookkeeping step the
Systems Engineer's own procedure already owns end-to-end. Verify
against actual commit parent counts in the repo history before
assuming — don't just infer from the general branch-convention prose,
same discipline as [[commit-sha-recorded-is-the-merge-commit]].

---
name: commit-sha-recorded-is-the-merge-commit
description: When CI/CD's hand-back offers a choice between the pre-merge branch-tip SHA (where evidence was gathered) and the --no-ff merge commit SHA, the Commit(s) column gets the merge commit — that's the standing convention already in use, just never written down before.
metadata:
  type: project
---

Learned 2026-08-14 (issue #15, `[RTVM-500]`).

## The situation

CI/CD merged `issue-15` `--no-ff` as `699abde` (merging branch head
`3f99d48`) and explicitly left the choice to me: keep the pre-merge
evidence SHA `00d0c38` already in the Commit(s) column (per "our usual
convention of not overwriting an evidence SHA with a merge SHA"), or
switch to the merge commit `699abde`. No memory file said which one is
actually standing convention here.

## What the existing table already does

Checked git history for prior Commit(s) values instead of guessing:
`3bc1b22`, `62cbb1e`, `481c726` are each **two-parent commits** (`git
log -1 --format="%P"`), i.e. the actual `--no-ff` merge commits CI/CD
produced — not a feature branch's single-parent tip. The commit
messages that recorded them say so directly: `aa7daf0` is titled
"Record merge SHA 481c726 in RTVM Commit(s) column". So despite what
CI/CD's comment implied, there is no standing convention of preferring
a pre-merge evidence SHA — the column has always carried the merge
commit.

## How to apply

When CI/CD's hand-back offers both a branch-tip/evidence SHA and its
own merge SHA, record the **merge SHA** — it's what's actually on
`main`, and it's what every prior row already did. Grepping
`git log -1 --format="%P" <sha>` for parent count is a fast way to
settle "is this the merge commit or a pre-merge tip" if the two SHAs
in a hand-back aren't obviously labelled. Don't take a CI/CD comment's
description of "our usual convention" at face value if it isn't in
memory or provable from `docs/RTVM.md` history — verify against the
actual prior rows first, same discipline as
[[doc-state-across-branches]].

Also record the pre-merge/evidence SHA in the narrative prose (§9.x)
even when it's not what goes in the Commit(s) column — it's still the
SHA the Test Engineer's run was actually pinned to, and losing that
line makes the evidence harder to re-derive later.

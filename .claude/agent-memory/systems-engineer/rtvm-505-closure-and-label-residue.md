---
name: rtvm-505-closure-and-label-residue
description: RTVM-505 (issue #20) closed as the last plan item — a straightforward no-regression-needed close, plus a `gh issue close` doesn't strip labels by itself.
metadata:
  type: project
---

Learned 2026-08-15 (issue #20, `[RTVM-505]`).

## The close itself

Textbook "Receiving a commit confirmation from CI/CD" terminal case: CI/CD
merged `issue-20` `--no-ff` as `68c9cde` and explicitly flagged no
regression testing needed (memory-files-only diff). Per
[[commit-sha-recorded-is-the-merge-commit]], replaced the pre-merge
evidence SHA `662b6ed` in the RTVM-505 Commit(s) cell with the merge SHA
`68c9cde` (confirmed two-parent via `git log -1 --format="%P"`), kept
status **Verified**, commented, closed. This was the last NFR / last row
in `docs/IMPLEMENTATION_PLAN.md` (priority 16) — nothing left downstream.

## `gh issue close` does not remove labels

After closing, `agent:systems-engineer` / `status:in-progress` /
`status:ready-for-commit` were all still attached — closing an issue is
orthogonal to its labels on this repo/gh version. Ran a separate
`gh issue edit --remove-label` pass afterward so the closed issue matches
the convention every other closed issue in this repo shows (label-free
except `type:requirement`). **How to apply:** when a terminal path ends
in `gh issue close` rather than a hand-off `gh issue edit`, don't assume
the close call cleans up stray `agent:*`/`status:*` labels — check
`gh issue view N --json labels` after closing and strip them explicitly
if any remain, so a later `gh issue list --label agent:X` sweep doesn't
pick up a closed issue by mistake.

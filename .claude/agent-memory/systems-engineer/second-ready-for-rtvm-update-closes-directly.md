---
name: second-ready-for-rtvm-update-closes-directly
description: A second status:ready-for-rtvm-update on the same issue (post-merge regression pass) closes the issue directly with no CI/CD hand-off unless it actually discharges an outstanding clause and promotes a row — don't apply the fast-path literally when nothing is promotable.
metadata:
  type: feedback
---

Learned 2026-08-14 (issue #11, RTVM-201/RTVM-402 — no promotion; contrast
with issue #10, §9.12 — promotion).

## The two outcomes look identical at the label level, but aren't

Both are a `status:ready-for-rtvm-update` handoff arriving a *second* time
on the same issue, after CI/CD already merged and asked for a regression
pass. The generic fast-path instruction ("update RTVM status, hand off to
CI/CD with status:ready-for-commit") is written for the *first*, ordinary
case and doesn't by itself distinguish these two:

- **Regression pass discharges the last outstanding clause** (typically
  V-1/DW-1, MSVC/`vstest` discovery-and-execution) → row(s) promote In Test
  → Verified. This *is* still routed to CI/CD despite being a docs-only
  diff — see [[fast-path-promotion-after-sha-recorded]]. Issue #10 §9.12:
  a corrected Windows harness (#24) made a genuine `vstest.console.exe` run
  possible for the first time, discharged V-1/DW-1, promoted six rows, and
  was still hand-off-to-CI/CD per convention.
- **Regression pass reconfirms only** — no new clause evidence, environment
  unchanged (still Ubuntu-only, no MSVC) → no status change at all. Close
  the issue **directly**, no CI/CD hand-off. Precedent: issue #9 §9.8.6.3
  ("the code is already on trunk... routing it there would produce a third
  regression round trip over a docs-only change") and issue #11 §9.13,
  which explicitly mirrors it.

## How to tell which one you're in

Read the Test Engineer's regression-pass comment for what environment it
ran on and whether it produced evidence for the specific clause the prior
§9.x.1 write-up named as outstanding. If it's still "Ubuntu agent runner,
no MSVC" and the outstanding clause was MSVC/`vstest`-shaped, nothing was
discharged — don't promote, don't route to CI/CD, write up the
reconfirmation and close. If a genuinely new capability landed (a fixed
script, a new runner, an actual Windows evidence artifact), it's the
promotion case.

## Why this matters

Routing a no-op docs update to CI/CD for the third time in one issue's
chain wastes a full agent round trip for zero information gain — CI/CD
would just report "nothing to commit, handing back," and the issue closes
anyway. The `docs/RTVM.md` writeup itself is what future readers need
(name the section, the SHA the row already carries, and which future
issue — #23 in this project — owns the still-outstanding clause); the
issue's job is done once that's recorded and the row's true state is
accurately stated in §5.

See [[fast-path-promotion-after-sha-recorded]], [[verification-platform-trap]].

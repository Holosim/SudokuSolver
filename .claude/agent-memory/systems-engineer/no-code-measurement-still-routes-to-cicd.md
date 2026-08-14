---
name: no-code-measurement-still-routes-to-cicd
description: A performance/measurement-only RTVM item (no source change, design margin large enough that the issue itself predicts "measurement not optimisation") that gets a first-time Approved→Verified promotion still takes the literal fast path to CI/CD, even though the only diff is docs/RTVM.md.
metadata:
  type: feedback
---

Learned 2026-08-14 (issue #15, `[RTVM-500]` performance budget, 10 s
worst case).

## The situation

RTVM-500's own issue body predicted this: `docs/SDD.md` §1.5's design
margin (MRV ordering) is ~3 orders of magnitude under the 10 s budget,
so the issue is a measurement exercise, not an optimisation one.
Software Engineer confirmed no source change was needed; Test Engineer
ran TP-500 on the §6.3 reference machine (issue's own SHA, not a prior
incidental one) and reported PASS with real exit-code-gated timing data
(worst case `hard17` at 28.6 ms, ~350x under budget). Handoff labeled
`status:ready-for-rtvm-update`.

## What to do — don't conflate with [[second-ready-for-rtvm-update-closes-directly]]

That memory's "close directly" rule is for a **repeat** handoff that
discharges nothing (the SHA is already recorded, nothing promotes).
This is different: RTVM-500 had **no SHA recorded yet** (Status was
still `Approved`) and this handoff is the row's **first** genuine
promotion to Verified. Even though the diff is `docs/RTVM.md` only (no
product code touched on the branch, matching the "measurement not
optimisation" framing), a real promotion happened — so the fast path's
literal instruction applies: update the row (Status → Verified, SHA
recorded), write up the evidence in a new `9.N` subsection, comment,
and hand off to `agent:cicd` with `status:ready-for-commit`. Don't
short-circuit to closing the issue yourself just because there's no
code for CI/CD to build — that judgment call belongs to CI/CD's own
hand-back (see [[fast-path-promotion-after-sha-recorded]]'s "closing
after CI/CD's hand-back" section), not to SE pre-empting it.

## Distinguishing rule of thumb

- Row already has a SHA, nothing new promotes → close directly, no
  CI/CD trip (`9.13`-style).
- Row has no SHA yet (or a stale one) and this handoff promotes it →
  fast path to CI/CD, even with a docs-only diff (`9.14`-style, this
  issue).

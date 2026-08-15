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

## Confirmed to generalize beyond RTVM-500 (2026-08-15, issue #19, RTVM-504)

Same shape recurred: RTVM-504's own issue body said outright "there is
no new code to write... there is a test to write correctly" (§7 I-12's
piecewise bound was already resolved during the SDD pass). Software
Engineer confirmed `git diff --stat` over `src/` was empty; Test
Engineer produced full real-Windows evidence (3 W-7 samples,
exit-code-gated, mutation-tested against a false-tightened ceiling to
rule out vacuous checks) and handed back with a PASS — no
`status:ready-for-rtvm-update` label this time (Test Engineer used the
role's own free-form comment + `**Next:** agent:systems-engineer`
instead), which didn't change the analysis: content, not the label,
determines the fast path.

Same treatment applied: `docs/RTVM.md` row promoted Approved → Verified
directly (not staged through In Test), Commit(s) set to the issue
branch's own evidence SHA (`d4d79b2`), narrative written in a new §9.N
section, `docs/RTVM.md` §9.4's A-row table entry for the same TP
cross-updated in place, committed straight to `main` (matching how
§9.14's commit for RTVM-500 landed — this is one of the exceptions to
"work happens on `issue-N` branches": a pure `docs/RTVM.md` bookkeeping
commit with no code lands directly on `main`, same as
[[commit-confirmation-pushes-direct-to-main]]), then handed to CI/CD
with `status:ready-for-commit`, asking CI/CD to report its `--no-ff`
merge SHA back so it can replace the evidence SHA in place (mirroring
a067772's follow-up on RTVM-500) without another status change.

**Generalized rule:** this pattern isn't specific to RTVM-500's
"measurement not optimisation" framing — it applies to *any* row where
(a) the issue's own body or the Software Engineer confirms no product
code changed, and (b) the Test Engineer's evidence is already complete
enough that nothing else is pending (no outstanding A-row clause like
ConPTY applies to *this* row specifically, even if it applies to
sibling rows sharing the same TP family — check the specific
row's own clauses, not the family's, before deciding whether to promote
straight to Verified rather than staging through In Test).

## Third instance (2026-08-15, issue #20, RTVM-505)

The last NFR in the plan, and a slightly different flavour: not a
timing measurement but a robustness assertion ("no input crashes the
finished program"). Same shape held anyway — the issue body itself
predicted this ("every earlier issue has to exist for the corpus to
mean anything"), Software Engineer confirmed `git diff --stat` over
`src/` on `issue-20` was empty, and Test Engineer's evidence (27-entry
TP-505 corpus, real Windows run at the branch tip, every case
exit-code-gated) was already complete with nothing else pending.
Promoted Approved → Verified directly (`docs/RTVM.md` §9.31), evidence
SHA `662b6ed`, fast path to CI/CD. Confirms the generalized rule isn't
limited to timing/measurement NFRs — it's about "no src/ change +
complete evidence", and a late-plan aggregate-property issue (depends
on everything else already existing) is exactly the shape most likely
to hit this pattern, not an exception to it.

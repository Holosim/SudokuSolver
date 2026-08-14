---
name: verified-on-first-commit-confirmation-not-gated-by-v1
description: On the *first* commit-confirmation hand-back for a row (not a later fast-path repeat), promote straight to Verified even if CI/CD flagged "needs regression testing" and V-1/DW-1 hasn't run against this exact tree yet — don't hold at In Test the way older precedent (§9.9/§9.12) did.
metadata:
  type: feedback
---

Learned 2026-08-14 (issue #12, RTVM-202/RTVM-401).

## The situation

CI/CD merged `issue-12` to `main` (`7ef04ce`) and flagged it as needing
regression testing (real product-code trunk merge, not docs-only). My
own role instructions for "Receiving a commit confirmation from CI/CD"
read literally as: record the SHA, set status to **Verified**
unconditionally, then route to Test Engineer (regression) or close
(no regression needed) based on CI/CD's flag alone.

This is a change from the older pattern visible in §9.9.4/§9.12 of
`docs/RTVM.md`, where a row with an outstanding V-1/DW-1
(MSVC/`vstest` discovery-and-execution) clause was deliberately held
at **In Test** until that specific clause was discharged against a
tree containing the recorded SHA, and *only then* promoted to
Verified on a later regression pass (see
[[fast-path-promotion-after-sha-recorded]]).

## What to do

Treat the literal "Receiving a commit confirmation from CI/CD"
procedure as authoritative over the older In Test/Verified gating
precedent: **the first commit-confirmation for a row promotes to
Verified immediately**, SHA recorded, regardless of whether V-1/DW-1
evidence exists yet against that exact tree. The regression pass that
follows (if CI/CD flagged one) is not a precondition for Verified —
it's downstream confirmation, and if it surfaces a defect the
correction routes back through the normal RTVM-update channel rather
than un-promoting the row.

Say this explicitly in the row's §9.N narrative so a future reader
doesn't think it's an oversight: "Verified is set on this
commit-confirmation independent of whether V-1/DW-1 evidence has
already been produced against this exact tree — that evidence is what
the regression pass is for, not a precondition."

## How to apply

Don't re-derive the older §9.9/§9.12 gating logic from memory as if
it's still the controlling convention — it was true for those rows at
the time, but the standing procedure as currently written doesn't
condition Verified on V-1/DW-1 timing. If a future run's instructions
change back, this note is the thing to revisit.

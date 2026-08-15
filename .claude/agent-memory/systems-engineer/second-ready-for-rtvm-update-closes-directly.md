---
name: second-ready-for-rtvm-update-closes-directly
description: A second status:ready-for-rtvm-update on the same issue (post-merge regression pass) closes the issue directly with no CI/CD hand-off unless it actually discharges an outstanding clause and promotes a row — don't apply the fast-path literally when nothing is promotable.
metadata:
  type: feedback
---

Learned 2026-08-14 (issue #11, RTVM-201/RTVM-402 — no promotion; contrast
with issue #10, §9.12 — promotion). Reconfirmed 2026-08-14 on issue #13
(RTVM-507, §9.21) — same shape as #12's §9.18: row already Verified at
commit confirmation, regression pass on that exact trunk tip adds only
bonus Windows evidence, nothing to promote, close directly. Reconfirmed
again 2026-08-14 on issue #16 (RTVM-203/RTVM-204, §9.24) — third
instance of the identical shape: commit confirmation promoted both
rows to Verified at `ce15599` in one comment (§9.23), then a *separate*
Test Engineer regression-pass comment arrived citing a *later* trunk
tip (`2199ac1`, itself the RTVM bookkeeping commit) with full real
Windows evidence pinned to that tip — still nothing to discharge since
the rows were already Verified, not In Test. Also removed
`status:ready-for-rtvm-update` explicitly on the direct-close label
cleanup this time (previous entries didn't call this out) — the label
set left on a directly-closed issue should match the `type:requirement`-only
precedent seen on #9/#13, not just drop the `agent:*`/`status:in-progress`
pair.

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

## Fourth Verified-row instance (2026-08-15, #19, RTVM-504)

Same shape again: row promoted to Verified at commit-confirmation
(`292af46` recorded), then a *separate* Test Engineer regression-pass
comment cited a later trunk tip (`82acc46`) with full real Windows
evidence (66/66 vstest, TP-504 exit-code-gated PASS on all 3 W-7
samples) — reconfirmation only, discharges nothing new (TP-501…503
still NOT-RUN, still owned by #25). Closed directly, wrote the
reconfirmation as a §9.29 follow-up rather than a new subsection (the
whole RTVM-504 story — first promotion, merge-SHA correction, and this
reconfirmation — now lives together in one place, which reads better
than scattering it across separate §9.x sections).

## The pattern also applies to rows still In Test, not only rows already Verified (2026-08-15, #17)

Every prior instance of this pattern involved rows already at **Verified**
reconfirming with nothing left to discharge. #17 (RTVM-004/005/006/007/
008/404/501/502/503, §9.27→§9.28) is the same shape one rung earlier: the
rows were **In Test**, with a specific named outstanding clause (A-4 —
automated coverage of the `Console`/tty `StdinKind` branch, reassigned to
#25). The regression pass (trunk `c33bb1d`, 14 commits of docs/memory-only
diff ahead of the last-tested tip) reconfirmed cleanly but produced
exactly the same NOT-RUN TPs/reason as the commit-confirmation evidence
already on record — it didn't touch the one clause that would have
promoted the rows. Closed directly, no CI/CD hand-off, rows left exactly
as §9.27 recorded them (In Test, SHA already present).

**How to apply:** don't assume this pattern is Verified-rows-only. The
test is always the same regardless of which status the rows currently
sit at: does this regression evidence actually discharge the *specific*
clause the last write-up named as outstanding? If not — reconfirm and
close, whatever status the rows happen to be at.

## Fifth instance, with a piggybacked row along for the ride (2026-08-15, #18, RTVM-405/406)

Same shape again: RTVM-405/RTVM-406 promoted to Verified at commit
confirmation (`a78f0d2`, §9.30), then a separate post-merge regression
pass reconfirmed identically (67/67, 49/49, byte-identical real-binary
exit-code/stdout numbers, same 47/55-PASS/8-NOT-RUN Windows shape as
#17) — nothing to discharge, both rows stayed Verified. Worth noting
explicitly: the piggybacked row (RTVM-300, In Test at `668f9a4`, not
this issue's own) also had nothing new to discharge and was left
untouched too — the "check every row this issue touches, not just its
own title" rule from the piggyback-discharge entries in
[[rtvm-conventions]] applies to the *closing* check as much as the
promoting one. Wrote the reconfirmation as a follow-up appended to the
existing §9.30 section (not a new §9.x number) — the sixth time this
project has preferred keeping one row's whole story in one place over
scattering it across sections, and cheaper than allocating (and
possibly colliding on) a new subsection number for a paragraph that
changes no status.

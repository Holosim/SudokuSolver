---
name: fast-path-promotion-after-sha-recorded
description: When a Commit(s) SHA is already recorded but status stayed In Test pending a regression pass, a later status:ready-for-rtvm-update PASS on a tree containing that SHA promotes straight to Verified — follow the literal fast-path hand-off to CI/CD even though nothing but docs/RTVM.md changed.
metadata:
  type: feedback
---

Learned 2026-08-14 (issue #10, `[RTVM-102]` group: RTVM-009/102/103/104/105/403).

## The sequence that produces this situation

1. CI/CD merges a feature branch, flags it as a trunk merge needing
   regression testing. SE records the SHA in Commit(s) but — per the
   standing "Verified needs full clause execution + SHA" convention —
   leaves Status at **In Test** if some clause (typically the
   MSVC/`vstest` V-1/DW-1 discovery-and-execution half) hasn't actually
   run against a tree containing that SHA yet. Hands to Test Engineer.
2. Test Engineer later produces the missing evidence on a tree that
   *does* contain the recorded SHA (e.g. trunk `main` after further
   unrelated merges), reports PASS, and applies
   `status:ready-for-rtvm-update`.

## What to do

Don't re-litigate whether this deserves promotion — §9.10.2 (RTVM-001/
002/003, issue #24) explicitly pre-committed to this: "recording the SHA
on the next commit-confirmation hand-back should move these straight to
Verified without a further regression round." Same logic applies in
reverse order here (SHA already recorded, evidence arrives after): if
the Test Engineer's new evidence runs on a tree containing the
already-recorded SHA and every clause is now covered, promote **In
Test → Verified** immediately, Commit(s) unchanged. Write a new `9.N`
subsection naming the run ID, what it discharged, and why the existing
SHA still applies (no code moved — diff since that SHA is docs/memory
only).

**Hand-off:** follow the fast-path instruction literally — "hand off
directly to `agent:cicd` with `status:ready-for-commit`" — even though
the only diff is `docs/RTVM.md`. Don't skip CI/CD just because it feels
like a docs-only edit that SE could commit unilaterally; the fast path
doesn't carve out an exception for that, and CI/CD's own hand-back is
what will actually let the issue close per the "commit confirmation"
section's closing rule.

See [[verification-platform-trap]] for the V-1/DW-1 background this
pattern depends on, and [[doc-state-across-branches]] for the general
"which tree is this evidence actually on" discipline.

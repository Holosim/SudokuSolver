---
name: commit-sha-updates-even-without-promotion
description: On a commit confirmation touching several RTVM rows, update the Commit(s) column for every row the merge touches, even a row that stays at In Test (not promoted to Verified) because it still has an open clause.
metadata:
  type: project
---

Learned 2026-08-15 (issue #22, RTVM-901/904/905/907 commit confirmation).

## The situation

CI/CD merged `issue-22` (`146a5d1`) and flagged "no regression testing
needed." Of the four rows this issue owns, three (RTVM-904/905/907)
had nothing left to discharge and promoted In Test → Verified per
[[verified-on-first-commit-confirmation-not-gated-by-v1]]. The fourth,
RTVM-901, still has its standing VS-2022-loader clause open (§9.4 A-2)
and correctly stays at In Test. The question: does RTVM-901's
Commit(s) column also move from the old scaffold SHA (`85bab27`) to
the new merge SHA (`146a5d1`), or does it stay put since the row isn't
promoting?

## What the precedent actually shows

§9.27 (issue #17's commit confirmation) is the clean answer: CI/CD's
merge SHA `2ca7deb` was "recorded in the Commit(s) column for all nine
rows this issue owns... Status stays In Test, not Verified." The SHA
update and the status promotion are two independent decisions — the
Commit(s) column records which tree the row's current evidence was
taken against, not a certification that the row is fully verified.
Contrast with §9.25's RTVM-900, which *also* stayed at In Test with
its SHA unchanged — but that's because issue #21 produced literally no
new evidence touching RTVM-900 at all (pure re-confirmation of an
unrelated row), not because "not promoted" implies "SHA frozen."

## How to apply

On a multi-row commit confirmation: update Commit(s) for every row the
merge actually produced new evidence for, regardless of whether that
row promotes to Verified or holds at In Test. Only leave a row's SHA
untouched if the merge genuinely didn't touch or re-exercise that row
at all (rare — usually every row an issue's body names got at least
reconfirmed). Don't conflate "held at In Test" with "nothing to
update" — check §9.27 (SHA moves, status doesn't) against §9.25
(neither moves, because no new evidence) before deciding, rather than
assuming either pattern is the default.

See also [[commit-sha-recorded-is-the-merge-commit]] (merge SHA, not
pre-merge evidence SHA) and [[verification-platform-trap]] (why a row
can have new evidence and still not promote).

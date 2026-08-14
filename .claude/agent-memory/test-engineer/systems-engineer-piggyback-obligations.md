---
name: systems-engineer-piggyback-obligations
description: The Systems Engineer sometimes attaches an extra RTVM obligation to an issue purely in-thread (not in the issue body), naming that issue as the vehicle because it already touches the same test file. Check the whole comment thread, not just the issue body, before signing off.
metadata:
  type: project
---

On #11 (2026-08-14) the Systems Engineer's first comment on the issue (not
the issue body) attached TP-200's new `P-SEARCH` clause to #11, reasoning
that #11 was "the next issue to touch `tests/SudokuSolver.Tests/
SolverTests.cpp`" and the clause was cheap to ride along (one fixture, one
method, no solver change). The comment was explicit that this doesn't
change RTVM-201's own scope, but was equally explicit that "what must not
happen is RTVM-200 reaching Verified without it."

The Software Engineer's implementation comment on the same issue made no
mention of it at all and did not add the fixture or method — an oversight,
not a deferral (nothing said "leaving this for #12").

**Why this matters:** the issue body alone is not the full spec. A
Systems Engineer comment mid-thread can add scope tied to *this* issue
number specifically because of file-touch timing, and that obligation is
easy to miss if you only diff the issue body against the delivered code.

**How to apply:** before signing off on any issue, re-read every comment
(not just the description) for phrases like "flagging it here now," "the
next issue to touch `<file>`," or "must not happen without it" — these mark
piggyback obligations. Check the actual repo state for whether they were
fulfilled, independent of whether the Software Engineer's own summary
comment mentions them. If missing, this doesn't necessarily fail the
issue's own named RTVM item(s) — Systems Engineer may have explicitly
decoupled scope — but it's still real undone work tied to *this* issue by
name, and should be handed back to the Software Engineer with the exact
quote, rather than let ride into whatever issue happens to touch the file
next.

Related: [[solver-coverage-limits]] (the underlying `P-SEARCH` gap this
obligation exists to close).

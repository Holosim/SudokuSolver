---
name: standing-spike-instructions-can-go-unfulfilled
description: A ledger row naming a future issue ("attempt this on #17") is a request, not a guarantee — check whether it actually happened before trusting the row, and reassign explicitly rather than silently dropping it
metadata:
  type: feedback
---

# A standing instruction in the RTVM is not self-enforcing

`docs/RTVM.md` §9.1.6/§9.4's A-4 row said, in writing, "remains the Test
Engineer's to drive on #17" (the ConPTY spike for TP-004…008's console
handle behaviour). #17 shipped its actual feature scope (RTVM-004…008,
RTVM-404, RTVM-501…503) cleanly, but neither the Software Engineer nor the
Test Engineer attempted the spike — both independently called a from-scratch
ConPTY harness out of scope for a feature branch, a reasonable call for
either of them to make individually, but one that leaves a documented
commitment unfulfilled with nobody positioned to notice except whoever next
reads that exact row.

**Why:** downstream roles read the issue body and the requirement text, not
the full §9.4 V-4 table — there is no mechanism that surfaces "this issue
also owes a ledger commitment from three issues ago" to them. The commitment
only resurfaces when the Systems Engineer (the only role that reads the
whole ledger on every pass) checks it against what actually happened.

**How to apply:** before writing a routine fast-path/commit-confirmation
ledger entry, grep the RTVM for the issue's own number in prose (not just in
its own line items) — `grep -n '#17'` here turned up the A-4 row
immediately. If a named commitment wasn't kept, don't silently let the row
go stale: state plainly that it didn't happen and *why* (both roles gave the
same reasoning independently — that's a real signal, not carelessness), then
either re-open it as its own dedicated issue (as done here, #25, mirroring
how #24 was split out of #9 for the same "not a feature branch's job" shape)
or explicitly re-scope it if it's no longer worth doing. Never let "the spike
wasn't attempted" quietly become "the spike doesn't need attempting."

**Consequence for status promotion:** a row with zero automated evidence of
any kind (not even a partial pipe/file substitute) does not get to ride
[[verification-platform-trap]]'s "first commit confirmation promotes to
Verified" precedent (`[[verified-on-first-commit-confirmation-not-gated-by-v1]]`)
just because everything else about the feature passed. That precedent was
earned by RTVM-203/204 having genuine MSVC `TEST_METHOD` evidence; RTVM-004…
008/404/501…503 on #17 do not have the equivalent for the `Console`
`StdinKind` shape specifically, so they stay In Test through the next
commit confirmation too, flagged explicitly in the ledger so the next reader
doesn't default to the literal "record SHA → Verified" instruction text
(see [[verification-platform-trap]]'s "Caught myself defaulting..." entry —
same trap, different row shape: here it's a genuinely missing clause, not
just an easy-to-miss project-wide blocker).

See [[verification-platform-trap]], [[pipeline-label-traps]].

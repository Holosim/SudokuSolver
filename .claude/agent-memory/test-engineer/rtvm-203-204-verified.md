---
name: rtvm-203-204-verified
description: RTVM-203/204 (abort latency, progress counter) PASSED 2026-08-14 on #16 — first RTVM-2xx item with a real end-to-end MSVC/vstest trx confirming literal TP timing numbers, thanks to the DW-1 fix.
metadata:
  type: project
---

Issue #16, branch `issue-16` tip `4694387`. Test-writing only — no production
code changed; the mechanism (`SolveControl::onPoll`, `nodesExplored`, the
RTVM-507 `minSolveDuration` hook) was already delivered at #8/#13.

**Both TPs independently mutation-checked, confirming the Software
Engineer's own falsifiability claim rather than just trusting it:**
disabling the RTVM-507 extension loop's abort check killed exactly
`rtvm203_*` + the pre-existing `rtvm507_anAbortDuringTheExtensionStops...`
test; resetting `m_nodesExplored` in `beginNewPass()` killed exactly
`rtvm204_*` + `rtvm507_hookKeepsPollingAndAdvancingTheNodeCounter...`. See
[[mutation-testing-runtime-logic]] for the general technique — this is a
second confirmed instance of "verify the SE's stated mutation yourself,
don't just read their claim."

**First RTVM-2xx-family issue where the real Windows `tests.trx` (not just
the Linux shim) gave a literal, checkable pass on the exact TP numbers**:
`rtvm203_*` ran `00:00:20.00...` (10 reps × 2 s), `rtvm204_*` ran
`00:00:11.00...` (the 11 s `minSolveDuration` margin), both
`outcome="Passed"`, 65/65 overall — no scaling-down of the literal TP-203/204
numbers on either platform. This only works because the DW-1 fix
([[windows-evidence-reading]]) landed at #23/#24 and is already an ancestor
of `issue-16`'s branch point; always check `git merge-base --is-ancestor`
before assuming a fix from a higher-numbered issue is or isn't present on an
older, previously-on-hold branch — issue numbering order and branch-ancestry
order are not the same thing (confirmed here: #23/#24 commits *are*
ancestors of #16 despite the lower number).

**Why:** establishes the "read the real trx per-method, not just the
aggregate count" habit pays off even for a two-method issue, and confirms
solver-side wall-clock RTVM rows are now empirically checkable end to end,
not just inspectable.

**How to apply:** any future issue touching `SolveControl`/abort/progress
timing — reuse both the mutation targets above and the trx per-method
duration cross-check before trusting a "verified falsifiable" claim.

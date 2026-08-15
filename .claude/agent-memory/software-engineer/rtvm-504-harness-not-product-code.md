---
name: rtvm-504-harness-not-product-code
description: Issue #19 (RTVM-504, never silent) needed zero product-code changes — the "test to write correctly" was tests/windows/run-timing.ps1, and TP-504 specifically doesn't need the ConPTY spike (#25) that TP-501..503 are still blocked on
metadata:
  type: project
---

Recorded 2026-08-15 on issue #19 (RTVM-504, piecewise-bound "never silent"
requirement, `docs/RTVM.md` §7 I-12).

**The mechanism was already built.** `SolveSession` (RTVM-501/502 prompt
cadence) landed on #17. RTVM-504 doesn't add behaviour — §7 I-12 rewrote a
single wrong 11.0s-from-launch bound into two: 16.0s to first output
(RTVM-501 + tolerance), then 11.0s between outputs thereafter (RTVM-502 +
tolerance). The issue body said this outright: "there is no new code to
write for I-12; there is a test to write correctly."

**"Test" here meant the process-level harness (`tests/windows/run-timing.ps1`),
not a `TEST_METHOD`** — TP-504 is in the 500-507 process-level band per
[[output-layer-scope-per-issue]]. Before this issue, `run-timing.ps1` had a
hardcoded loop that marked TP-501..504 all `NOT-RUN` behind one probe
(`Test-DiagHookActive`), unconditionally, regardless of whether the
RTVM-507 hook was actually active — a leftover from when #23 wrote it
*before* #17's hook landed, per that issue's own P4 spec ("these rows flip
to executable automatically... no script edit needed" — which turned out
to require an edit after all, since the loop never checked `$probe.Active`
before writing NOT-RUN).

**The key realization that scoped the fix correctly: TP-501..503 and
TP-504 are not the same kind of test, even though they share a NOT-RUN
loop.** TP-501 (prompt timing), TP-502 (repeat interval) and TP-503
(solve continues during a prompt) all read naturally as needing to *watch
prompts arrive*, which looks like it needs the same interactive console
#25 (ConPTY spike) is chasing for TP-004/005/006. But RTVM-006/008 mean a
prompt never requires a reply and a non-interactive invocation is never
blocked — so TP-504 ("no gap larger than the bound, ever") can be
driven today with plain redirected stdin/stdout/stderr, no ConPTY needed.
TP-501/502/503 stay `NOT-RUN` in this harness (unchanged, out of this
issue's scope) — not because they need ConPTY either, but because
implementing them wasn't what issue #19 asked for; that's a separate,
narrower follow-up if anyone wants automated (rather than hand-run)
TP-501..503 evidence before #25 lands.

**What got built:** `Invoke-SudokuTimestamped` and `Measure-NeverSilent`
in `tests/windows/lib/Common.ps1`, wired into `run-timing.ps1`'s TP-504
block covering all five cases the procedure names (P-EASY, P-HARD17,
P-UNSOLVABLE, P-BADCHAR, and the long-solve hook run to 60s). See
[[powershell-mandatory-and-list-gotchas]] point 4 (blocking-wait timestamp
clustering) and point 1b (the `Sort-Object` single-item unroll) for two
real bugs this surfaced, both caught by validating against a Linux g++
build before handoff — neither would have been visible from reading the
code alone.

**How to apply:** when an RTVM item's Design pointers or issue body point
at "no new behaviour, a test/assertion problem," check which TP band it's
in (unit vs. process-level, [[output-layer-scope-per-issue]]) before
assuming there's nothing to write — a process-level TP still needs real
harness code, it's just not a `TEST_METHOD`. And when a requirement shares
an existing NOT-RUN reason with siblings that are blocked on something
real (here, #25), verify independently whether *this* requirement's own
wording (RTVM-006/008 for RTVM-504) actually needs the same blocker before
accepting the shared NOT-RUN as correct for all of them.

Related: [[output-layer-scope-per-issue]], [[powershell-mandatory-and-list-gotchas]],
[[rtvm-500-no-code-needed]], [[rtvm-506-no-code-needed]].

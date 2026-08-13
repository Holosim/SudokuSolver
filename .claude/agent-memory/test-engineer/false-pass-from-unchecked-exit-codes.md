---
name: false-pass-from-unchecked-exit-codes
description: A timing/behaviour check that verifies wall-clock or output-content but never checks the child process's exit code can report PASS on a run that never executed the product at all
metadata:
  type: feedback
---

When reading Windows evidence JSON (or any generated PASS/FAIL ledger),
**always check the recorded exit code alongside whatever the check claims
to measure**, even when the row says PASS. A PASS field is only as
trustworthy as the weakest condition it was computed from.

**Why:** on #23 (2026-08-13), `tests/windows/run-timing.ps1`'s TP-500
budget check computed `$withinBudget` from wall-clock time only
(`$max -le 10000 -and -not $anyTimedOut`) and never looked at
`$exitCodes`. All ten runs of all three fixtures had exited `-1`
(a PowerShell-layer launch failure, not the product running) with
near-zero elapsed time, and the check still reported PASS — "the
10-second performance budget holds" was asserted from ten runs of a
different program failing to start. Independently, `tests/windows/run-
procedures.ps1`'s TP-406 stream-separation check ("stdout contains none
of these forbidden substrings") passed for the same reason: an empty
stdout from a crashed launch trivially contains no forbidden substring.
Both are worse than an honest FAIL — they read as clean evidence for
the client's stated core requirement while proving nothing.

**Root cause that produced it**: `Invoke-Sudoku` in
`tests/windows/lib/Common.ps1` defaulted `-RedirectStandardInput` to
the literal string `'NUL'` when no stdin file was supplied, which
threw on the Windows runner and was silently caught (`exit=-1`,
`LaunchError` captured in the return hashtable but never surfaced by
any caller into the evidence JSON). Every call site omitting
`-StdinFile` failed identically — 39/55 checks in one run.

**How to apply:** when a "the deliverable performs within budget"
or "stream stays clean" style check passes, look for the exit code /
success signal it should logically depend on but structurally doesn't
have to. If a script's PASS condition is `some measurement <=
threshold` with no `exitCode == expected` term, treat that as a defect
in the harness even if every individual row currently reads PASS —
the absence of the check is the bug, independent of whether it
happened to bite this run. Also check whether a captured diagnostic
field (like `LaunchError`) is actually threaded through into the
written evidence, or just computed and dropped — "the data exists
somewhere in the script" is not the same as "the data reached the
artifact."

**Confirmed fixed, same day**: `b4dfe0f` fixed the stdin default (real temp
file instead of `'NUL'`), added `Get-FailureReason` to thread `LaunchError`
into every FAIL row's `Reason`, gated TP-406 on `ExitCode -eq ExpectedExit`
before the substring check, and gated TP-500's `$withinBudget` on
`-not $anyWrongExit`. Re-run on the pushed-together tip (`3658728`) showed
genuine solve latencies (7-30ms, well under the 10s budget) with all exit
codes correct — real evidence, not crash latency. **How I verified the
fix was real and not just "the FAIL rows went away"**: read the source of
the gating condition itself (`grep` for `anyWrongExit`/`ExpectedExit` in
the `.ps1`), not only the JSON — a check that happens to pass this run
could still be missing the gate. Confirming the *condition exists in code*
is stronger evidence than confirming *this run's numbers are plausible*.

Also surfaced seven genuinely-new-looking FAIL rows on the same re-run
(TP-009/401/402/403) — correct exit codes, empty/absent wording. These
were previously invisible because the stdin bug crashed those cases before
the product ever ran; fixing the launch bug made pre-existing, already-
scoped-elsewhere gaps ([[stub-wording-vs-exit-codes]], deferred to #10/#11)
visible for the first time. Don't mistake "a fix exposed more FAIL rows"
for "the fix caused a regression" — check whether each newly-visible FAIL
is a known deferred item before reporting it as new breakage.

Related: [[windows-evidence-reading]], [[test-engineer-cannot-author-repo-files]], [[stub-wording-vs-exit-codes]].

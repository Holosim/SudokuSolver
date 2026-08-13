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

Related: [[windows-evidence-reading]], [[test-engineer-cannot-author-repo-files]].

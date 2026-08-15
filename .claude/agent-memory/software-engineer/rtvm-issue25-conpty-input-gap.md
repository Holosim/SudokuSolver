---
name: rtvm-issue25-conpty-input-gap
description: Issue #25 (A-4 ConPTY spike) landed after 10+ Windows-CI rounds — genuine PASS on TP-004/most of TP-006, isolated negative on console-input delivery for TP-005/TP-006-stop, plus a real process gap (silent multi-round work with no comment) to watch for
metadata:
  type: project
---

Recorded 2026-08-15 on issue #25 (docs/RTVM.md §9.4 A-4, ConPTY spike for
TP-004…008 console-handle behaviour).

**The technical result.** `tests/windows/lib/ConPty.ps1` is a real
`CreatePseudoConsole` driver (raw `ReadFile`/`WriteFile` on the pty pipes,
not .NET `FileStream` — `FileStream`'s internal read-ahead heuristics
silently stopped delivering data after the first `Read()` call, an early
round's finding worth remembering if anyone builds another ConPTY harness
in .NET/PowerShell). `tests/windows/run-procedures.ps1` drives
`SudokuSolver.exe` under it for TP-004/005/006. On the hosted
`windows-latest` image this repo's CI uses: **prompt *output* over ConPTY
works and TP-004 (both clauses) plus TP-006's cadence/still-running
clauses are a genuine PASS.** Console *input* does not: three
progressively-tighter isolation probes (nested `cmd.exe`, then
`powershell.exe` with no `cmd.exe` but still a redirect wrapper, then true
direct attachment with zero intermediaries, result reported via a file
write from inside the child) all agree that bytes written host-side to
ConPTY's input pipe never surface as a console input event on this image
— `GetNumberOfConsoleInputEvents` stays 0, `ReadConsoleA` never unblocks,
even measured from inside the directly-attached child. That's the
isolated negative result for TP-005/TP-006's stop-response clauses: not a
defect in `StdinChannel.cpp`/`SolveSession.cpp` (those are never reached —
the console handle never receives the write in the first place), and not
vague either — three independent eliminations of confounders (cmd.exe
wrapping, encoding, output-rendering-vs-file-write reporting) all landing
on the same conclusion is what "specific negative result, not a vague
one" (the issue's own bar) looks like in practice.

**The process gap worth remembering.** The branch (`issue-25`) had 10
real, evidence-producing Windows-CI rounds of work already pushed —
genuine progress, not spinning — but *no comment had ever been posted*
recording any of it. The issue sat at `status:in-progress` through at
least 9 hourly `stall-recovery.yml` retriggers with the thread completely
silent, each one just re-adding `agent:software-engineer` without new
visible activity. The handoff-comment mandate ("post one comment before
you finish, no matter what") exists exactly to prevent this — a reader
looking at the issue thread alone had zero visibility into 10 rounds of
real diagnostic work. When you pick up a branch like this: read the
branch's own commit history and its CI run history (`gh run list
--branch <branch>`) before assuming the issue thread is the full record —
work can be real and substantial even when the comment thread is silent,
but don't let your own turn end without breaking that silence.

**How to apply:** when a multi-round diagnostic spike has converged on
the same negative result from several independently-designed isolation
attempts, that convergence *is* the stopping condition — don't keep
adding probes hunting for a way to make it pass. Write the conclusion
into the artifact the next role reads (this round moved it from a
scattered `conpty-diag.txt` note into the actual FAIL `reason` strings in
`runtime-procedures.txt`), verify the harness script still parses
(`[System.Management.Automation.Language.Parser]::ParseFile`, no local
pwsh execution possible without a real Windows console anyway) and that
the pushed commit's own Windows CI run reproduces byte-identical
PASS/FAIL/NOT-RUN outcomes, then hand off — don't treat "still failing on
this one clause" as license to keep iterating past the point of
diminishing evidence.

Related: [[rtvm-504-harness-not-product-code]], [[output-layer-scope-per-issue]].

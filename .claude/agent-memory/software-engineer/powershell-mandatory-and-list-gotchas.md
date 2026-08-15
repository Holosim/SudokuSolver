---
name: powershell-mandatory-and-list-gotchas
description: PowerShell surprises that silently break evidence-collection scripts (tests/windows/*.ps1) — List<T>/pipeline unrolling (return AND Sort-Object), Mandatory params rejecting empty input, Start-Process -RedirectStandardInput 'NUL' throwing on real Windows, and Register-ObjectEvent timestamps clustering under a blocking wait
metadata:
  type: reusable-solution
---

Hit while writing `tests/windows/run-procedures.ps1` / `run-timing.ps1` and
`tests/windows/lib/{Common,Fixtures}.ps1` for issue #23. Both are measured on
`pwsh 7.6` on the Linux agent runner (see [[no-msvc-in-agent-runner]] — `pwsh`
itself *is* available there even though MSVC isn't, so these scripts can be
smoke-tested end-to-end before handoff).

**1. A function that `return`s a `System.Collections.Generic.List[T]` gets
that list silently unrolled by the pipeline.** If the list is empty at
return time, the caller's variable becomes `$null`, not an empty list —
every later `.Add()`/mandatory-param call on it then fails with a confusing
"Cannot bind argument ... because it is null", often deep inside an
unrelated `try/catch`.

**Fix:** always `return , $list` (leading comma — wraps it as a single
pipeline item so it isn't unrolled). Applies to *any* collection return,
not just empty ones, but empty is where it bites first since `New-Object
List[T]` starts empty by construction.

**1b. The same unroll bites through `Sort-Object`, not just `return` — and
this time it's the *one-item* case that bites, not the empty one.** Found
writing `Invoke-SudokuTimestamped`/`Measure-NeverSilent` for issue #19
(TP-504): `Events = ($sync.Events | Sort-Object Ms)` where `$sync.Events`
is a `List<object>` of captured stdout/stderr lines. When the run produces
exactly one line of output, `Sort-Object` emits exactly one pipeline
object, and assigning a one-object pipeline to an untyped variable gives
back that bare object, not a one-element array. The bare hashtable's own
`.Count` (its key count — coincidentally 3, since each event record is
`@{ Stream; Ms; Text }`) then reads as a plausible-looking event count,
and `$sorted[0]` becomes a *hashtable key lookup* (key `0`, which doesn't
exist) returning `$null` instead of the first event. The observable
symptom was a false FAIL — "process produced zero bytes on either
stream" — against a run that had genuinely produced one line of output,
caught only by validating against a real (Linux g++) build before
handoff, not by reading the code. **Fix:** wrap every `X | Sort-Object
...` assignment in `@(...)` to force array-ness regardless of item count:
`Events = @($sync.Events | Sort-Object Ms)`, and again at the consuming
end (`$sorted = @($Events | Sort-Object Ms)`) — a `[array]`-typed
parameter auto-wraps a scalar argument back into a one-element array at
the call boundary (verified directly), but that protection is gone the
moment the value is re-piped through anything inside the function.
**Generalizes to:** any pipeline stage (not just `return`) can unroll a
collection down to its bare single element — treat `@(...)` as mandatory
around every `| Sort-Object` / `| Where-Object` / `| Select-Object` whose
result gets indexed or `.Count`-checked afterward, not just at the
function boundary point 1 already covers.

**2. `[Parameter(Mandatory)]` on a `[string]` or `[string[]]` parameter
rejects a legitimate empty string/collection**, even with
`[AllowEmptyCollection()]` — for `[string[]]`, a single-element array whose
one element is `""` (exactly what `"" -split "\`n"` produces from an empty
process-output capture) still fails with "it is an empty string", not
"empty collection". `[AllowEmptyString()]` fixes the scalar-string case;
for the array case there's no attribute that reliably fixes it — drop
`Mandatory` and validate manually instead (see `ConvertTo-GridBlock` /
`Test-GridBlockShape` in `tests/windows/lib/Common.ps1` for the pattern:
`if (-not $Rows -or $Rows.Count -ne 9) { throw ... }`).

**Also worth knowing, not a bug:** `Start-Process` and `Join-Path` report
their own failures (bad redirect target, unresolvable path) as
*non-terminating* errors by default — `try/catch` does not intercept them,
so they print straight to the job log even from inside a function that
means to handle them. Pass `-ErrorAction Stop` on the call itself to make
`try/catch` actually catch it.

**How to apply:** any future `tests/windows/*.ps1` work (or other
PowerShell CI tooling) should smoke-test against a throwaway shell-script
stand-in `.exe` on the Linux runner before handoff — it won't catch
Windows-only behaviour, but it does catch exactly this class of "the
script crashes on its own error-handling path" bug, which is otherwise
invisible until the first real Windows run. `Set-StrictMode -Off` was kept
deliberately in `Common.ps1` for the same reason: strict mode turns *more*
of these edge cases into hard failures, which cuts against C1 ("never
throw out of a probe") for a script whose whole job is to survive
surprising input.

**3. `Start-Process -RedirectStandardInput 'NUL'` throws before the child
process launches — on a real Windows runner, not on the Linux smoke test.**
This one the Linux smoke test in point 2 above *cannot* catch, because
`pwsh` on Linux doesn't reject the bare string the same way; it was only
found by the Test Engineer running the actual Windows job (issue #23,
2026-08-13). `Invoke-Sudoku`'s `try/catch` correctly turned the throw into
evidence (`ExitCode = -1`, `LaunchError` set) rather than crashing — but
every call site that omitted `-StdinFile` then failed identically and
near-instantly (~0.4-0.9ms), and two downstream checks derived a false
**PASS** from that failure rather than a FAIL: one that asserted "stdout
contains none of these forbidden substrings" (trivially true of empty
stdout) and one that measured elapsed time only, without checking the exit
code (so it timed the launch failure, not the solver, against the
performance budget). **Fix:** redirect stdin from a real, freshly-created
empty temp file (`[System.IO.Path]::GetTempFileName()`) instead of the
device-name literal — same closed-stdin/immediate-EOF semantics, no throw.
**Generalizes to:** (a) any check whose PASS condition is "absence of a
forbidden signal" rather than "presence of the expected one" is at risk of
reading a launch/harness failure as a pass — cross-check against the exit
code actually reaching what the fixture class defines, not just the
content; (b) a result hashtable's error-detail field (here, `LaunchError`)
is only useful if every caller that builds a FAIL `Reason` actually reads
it — centralize that into one helper (`Get-FailureReason` in `Common.ps1`)
rather than trusting each of a dozen call sites to remember.

**4. `Register-ObjectEvent -Action` invocations queue behind a blocking
call on the same thread — a synchronous `$proc.WaitForExit()` starves
them until it returns, destroying the very timestamps they exist to
capture.** Found writing `Invoke-SudokuTimestamped` for issue #19
(TP-504's byte-level gap analysis over `OutputDataReceived`/
`ErrorDataReceived`). The .NET event itself fires on a thread-pool thread
the instant a line arrives, but the actual PowerShell script block passed
to `-Action` only *runs* when the single-threaded runspace's event queue
gets pumped — which does not happen while that same thread is blocked
inside a synchronous `$proc.WaitForExit(ms)`. Measured directly (see the
polling-vs-blocking comparison in the issue #19 handoff): with a blocking
wait, three lines written 200ms apart all read back within ~3ms of each
other, right at process exit — a total, silent loss of the timing signal,
not a crash or a visible error. **Fix:** replace the blocking wait with a
short poll loop (`while (-not $proc.HasExited -and ...) { Start-Sleep
-Milliseconds 20 }`) so the thread yields back to the engine often enough
for queued actions to actually dispatch as they happen. **Generalizes
to:** any use of `Register-ObjectEvent` (not just process I/O) on a
script that also does its own synchronous waiting needs to poll, not
block, for the same reason — this is a property of the single-threaded
pwsh runspace, not of `Process` specifically.

---
name: powershell-mandatory-and-list-gotchas
description: Two PowerShell surprises that silently break evidence-collection scripts (tests/windows/*.ps1) — return a List<T> and Mandatory string/string[] params rejecting legitimate empty input
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

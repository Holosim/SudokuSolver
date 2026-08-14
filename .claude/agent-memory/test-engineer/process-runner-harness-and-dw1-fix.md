---
name: process-runner-harness-and-dw1-fix
description: Issue #24 built sudoku::test::ProcessRunner (real CreateProcess/fork end-to-end harness) and, separately, tests/windows/run-procedures.ps1 now uses the correct /ListTests:<dll> syntax — DW-1 is fixed there, giving genuine MSVC discovery+execution evidence for the first time.
metadata:
  type: project
---

**#24 (2026-08-14) landed `sudoku::test::ProcessRunner`**
(`tests/SudokuSolver.Tests/ProcessRunner.h/.cpp`), the harness `docs/SDD.md`
§3.3 had specified since the start but nobody had built (see
[[console-layer-end-to-end-now-runnable]] for the state before this). It
spawns the built exe with pumped stdout/stderr on separate threads (the
deadlock the issue warns about), an EOF-terminated stdin writer thread, a
timeout with forced termination reported as a distinct flag, and a
`_WIN32` branch (`CreateProcess`) mirrored by a POSIX branch (`fork`/`exec`)
so the harness itself executes on this pipeline's Linux agents, exactly like
`StdinChannel.cpp`'s seam. TP-001/002/003 were ported onto it as the first
tenants (`EndToEndTests.cpp`).

**Verified independently, not just re-read:** g++ compile clean; a `/tmp`
driver (discovered 30 methods, up from 25 pre-#24, all 30 pass) linking only
`SudokuCore` + the harness against a g++-built console binary; 9 standalone
stress checks against the harness API directly (spawn-failure, timeout+kill,
the specific 300KB/300KB dual-stream deadlock scenario, `Bytes`/`Closed`/`File`
stdin modes, NUL-byte preservation, the CRLF helper, and confirming SIGPIPE's
disposition is `SIG_DFL` inside the spawned child rather than leaking the
parent's `SIG_IGN`); and a falsifiability mutation on `InputSource.cpp`
(make the file argument always defer to stdin) that failed exactly the 4
tests that should notice and left TP-003 (no file argument) passing, as it
should.

**Bigger finding, not this issue's product but load-bearing for future V-1
readings:** the *hardcoded* vstest step inside `.github/workflows/windows-
verification.yml` ("TP-905 — unit tests discovered and executed by
vstest.console") is **still DW-1-broken** — its `/ListTests:"$PWD\...\
discovered-tests.txt"` is still the malformed syntax (treats the output path
as a positional test-source argument), still exits 1, and is still masked
green by `continue-on-error` exactly as [[windows-evidence-reading]]
describes. **But `tests/windows/run-procedures.ps1` (a Test Engineer-owned
script from an earlier issue, see [[test-engineer-cannot-author-repo-files]])
uses the corrected syntax, `/ListTests:$TestDll`,** and on this run genuinely
discovered all 30 methods and executed all 30 for real through
`vstest.console.exe` on Windows Server 2025 / MSVC 14.44 — including the five
new `EndToEndTests` methods, meaning the shipped `_WIN32` `CreateProcess`
branch of `ProcessRunner` actually ran on real Windows, not just compiled.
`runtime-procedures.txt` records `[PASS] TP-905 / discovery` and
`[PASS] TP-905 / execution` with the full 30-name list and `exit=0
total=30 passed=30 failed=0`. Cross-checked against `tests.trx` directly
(`outcome="Passed"` for all five `rtvm00N_*` entries) rather than trusting
the summary line alone.

**Why the distinction matters:** two different things can both be named
"TP-905" in the same run — one broken and masked, one fixed and genuinely
green. Read `runtime-procedures.txt`/`tests.trx` (the Test Engineer's own
script's output) for the verdict, not the workflow's own inline step, which
is legacy and should probably be removed or fixed by whoever owns the
workflow file next — flag it as an observation, not a defect blocking this
issue, since the corrected path already supersedes it.

**How to apply:** when reading `windows-verification` evidence going
forward, check `runtime-procedures.txt` for `TP-905 / discovery` and
`TP-905 / execution` rows first — that is the live, correct measurement.
The inline workflow step of the same name is stale and its failure is
already known and already worked around.

Related: [[windows-evidence-reading]], [[console-layer-end-to-end-now-runnable]], [[false-pass-from-unchecked-exit-codes]].

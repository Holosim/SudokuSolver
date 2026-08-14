# Software Engineer — memory

## Architecture patterns

- [SudokuSolver module layout](sudoku-module-layout.md) — the scaffold decisions that `DELIV` inspections read; don't undo them casually.

## Platform-specific notes

- [No MSVC in the agent runner](no-msvc-in-agent-runner.md) — runs are Linux/g++; how to compile-check a VS 2022 deliverable anyway.
- [Console layer platform seam](console-layer-platform-seam.md) — three functions in `StdinChannel.cpp` keep the Windows deliverable runnable on the Linux agent.
- [Blocking is allowed before the solve](blocking-is-allowed-before-the-solve.md) — why `readLineBlocking` exists and where the RTVM-006/008 ban actually bites.
- [CppUnitTestFramework and the static CRT](msvc-cppunittest-crt.md) — why a `/MT` exe forces the test project to compile core sources itself.

## Reusable solutions

- [RTVM-507 diagnostic hook](rtvm-507-diagnostic-hook.md) — why the extension reuses one `Search` instance instead of rebuilding it per pass, and the RTVM-203/204 continuity trap that would hide.

- [Parser fault precedence](parser-precedence-reading.md) — why `parseGrid` is three passes, and how the TP-106 interior-space conflict was ruled (§7 I-15).
- [Contradiction pass and fault wording](contradiction-pass-and-fault-wording.md) — RTVM-104's row-major scan order, box numbering in messages, and what RTVM-102..105/009/403 wording is (and isn't) pinned to.
- [Making invariants compile-time](making-invariants-compile-time.md) — the enum/static_assert/exhaustive-switch tricks this project uses instead of runtime checks.
- [Solver search shape](solver-search-shape.md) — one search covers RTVM-200/201/202; measured margins and which mutations TP-200 can't catch.
- [Output layer scope per issue](output-layer-scope-per-issue.md) — SDD §3.3's unit-vs-process TP split; don't write TEST_METHODs for TP-401+.
- [RTVM-500 needed no code](rtvm-500-no-code-needed.md) — recognising a genuine measurement-only issue, and what to still verify before saying so.
- [RTVM-506 needed no code](rtvm-506-no-code-needed.md) — static-CRT settings and dumpbin evidence already landed at #5; #14 was a verification pass, not new implementation.
- [TP-202 instrumentation needs P-BLANK](tp202-instrumentation-needs-p-blank.md) — P-NONUNIQUE's tree is exhausted regardless of the solution cap, so the "did not continue" proof has to run on P-BLANK instead.
- [RTVM-203/204 wall-clock tests](rtvm203-204-wallclock-tests.md) — literal TP-203/204 numbers kept as-is, and the mutation trap: `m_aborted` isn't what decides the outcome during the RTVM-507 extension, the loop's own return-value check is.
- [PowerShell Mandatory/List gotchas](powershell-mandatory-and-list-gotchas.md) — `return $list` unrolls to `$null`; `Mandatory` rejects empty input; `-RedirectStandardInput 'NUL'` throws on real Windows and can produce false PASSes downstream.
- [RTVM-004 prompt/abort/non-blocking stdin](rtvm-004-prompt-abort-nonblocking-stdin.md) — the fourth `StdinChannel` seam function, why `select()` mirrors all four Win32 availability tests, and why only `Reporter`'s Aborted branch (not `SolveSession`) got a unit test.

## Process

- [Unit tests are the Software Engineer's to write](unit-tests-are-the-software-engineers-to-write.md) — Test Engineer is hook-blocked from writing files; ship TEST_METHODs with the feature.

## Coding standards

- `docs/SDD.md` §2.1–§2.9 is the authoritative standard for this project (naming, const-correctness, `enum class`, no raw `new`, test methods prefixed with the RTVM ID they verify).

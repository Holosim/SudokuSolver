---
name: rtvm-505-no-code-needed
description: Issue #20 (RTVM-505, robustness corpus) required zero source changes — the bounded-read cap (I-13), byte-oriented parser, and main.cpp catch-all already existed, and the 26-entry TP-505 corpus already lives in run-procedures.ps1
metadata:
  type: project
---

Recorded 2026-08-15 on issue #20 (RTVM-505, "no input causes an unhandled
exception... every run terminates"). Same shape as [[rtvm-500-no-code-needed]]
and [[rtvm-506-no-code-needed]]: this is a property of the finished program
(priority 16, last NFR issue per `docs/IMPLEMENTATION_PLAN.md` line 56/69),
so by the time its dependencies (#5, #18) closed, everything it needs had
already landed as a side effect of earlier issues.

**What was already in place, checked directly rather than assumed:**
- `src/SudokuSolver/InputSource.cpp`'s `BoundedText` stops at `kGridSize`
  lines and caps any single line at `kMaxLineBytes` (4096, RTVM §7 I-13) —
  this alone is what makes the 1 MB single-line and 10 000-line corpus
  cases resolve in microseconds instead of buffering megabytes.
- `src/SudokuCore/Parser.cpp` is fully byte-oriented (`std::string_view`,
  explicit sizes, no `strlen`/NUL-terminator assumption) — a NUL byte, a
  UTF-8 BOM, full-width digits, and raw `.exe` bytes are all just illegal
  characters at a position, never UB.
- `src/SudokuSolver/main.cpp`'s `main()` wraps `run()` in
  `catch (const std::exception&)` / `catch (...)`, mapping any internal
  fault to `ExitCode::InvalidInput` (1) — the only RTVM-405 code meaning
  "no result, something was wrong with this run."
- `tests/windows/run-procedures.ps1`'s TP-505 section already builds a
  26-entry corpus (8 hand-built edge cases + all 16 `Get-Fixtures` fixtures
  + directory-arg + locked-file-arg — comfortably over the ≥25 the
  procedure requires) and asserts exit ∈ {0,1,2,3}, no crash text, under
  60 s, for every entry.

**What was verified fresh, not just read:** built the real
`src/SudokuCore + src/SudokuSolver` sources with g++
(`-std=c++17 -O2 -DNDEBUG -Wall -Wextra`, [[no-msvc-in-agent-runner]]) and
ran a hand-built copy of the TP-505 corpus (empty, single newline, P-BLANK,
10k lines, 1 MB line, NUL byte, BOM, full-width digits, binary-from-exe,
directory arg, zero-byte file, plus the five §6.1 samples) directly against
it. Every run: instant, exit code in {0,1,2,3}, no exception text. This is
not TP-505 itself (that's the Windows harness, process-level per
[[output-layer-scope-per-issue]]) — it's the same kind of sanity proxy
[[rtvm-500-no-code-needed]] used, confirming the Linux build hasn't
regressed anything TP-505 will check on Windows.

**How to apply:** when an RTVM item's dependencies point at "everything
upstream already had to get this right" (adversarial/aggregate NFRs late
in the plan), check the actual source for the specific properties the
requirement names before assuming a gap — RTVM-505 in particular is highly
likely to already be satisfied by whatever satisfied RTVM-102/103/106/405
individually, because those *are* the byte-level rules a crash would come
from violating.

Related: [[rtvm-500-no-code-needed]], [[rtvm-506-no-code-needed]],
[[output-layer-scope-per-issue]], [[no-msvc-in-agent-runner]].

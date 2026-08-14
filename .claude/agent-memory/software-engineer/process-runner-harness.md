---
name: process-runner-harness
description: How sudoku::test::ProcessRunner (issue #24) is shaped, and the SIGPIPE-inheritance bug found while stress-testing it
metadata:
  type: project
---

`tests/SudokuSolver.Tests/ProcessRunner.{h,cpp}` (added 2026-08-13, issue #24)
is the SDD §3.3 end-to-end harness: spawn `SudokuSolver.exe`, capture stdout
and stderr binary-safely, drive stdin in three modes (`Closed` / `Bytes`,
written on its own thread then closed for EOF / `File`), enforce a timeout
with forced termination. It's the second file in the repo (after
`StdinChannel.cpp`) with a real `_WIN32`/POSIX seam — same motivation, same
shape: the `_WIN32` branch (`CreateProcess` + anonymous pipes) is what ships,
the POSIX branch (`fork`/`exec`/`pipe`) ships nothing but lets these
procedures run for real on the Linux agent.

**Why it's a class with two full `run()` implementations, not shared leaf
functions like `StdinChannel`:** stream pumping, timeout enforcement and
process lifecycle differ enough between Win32 and POSIX that a shared
"seam of three functions" would have obscured both. `StdinChannel` factors
down to acquire/classify/read; a process spawner doesn't factor that small
without losing the deadlock-avoidance and timeout logic that's the actual
point.

**The deadlock the SDD warns about is real and testable directly**: spawn a
shell child that writes >64KiB (a pipe's buffer) to *both* stdout and stderr
before exiting. Draining one stream to EOF before touching the other hangs
on exactly this. Concurrent reader threads are what fixes it — verify with
this exact shape before trusting the harness, not just with small fixtures
that never approach a pipe's buffer size.

**Real bug found by stress-testing, not by inspection:** the parent process
ignores `SIGPIPE` (so a child that exits mid-write can't kill the whole test
binary). `SIG_IGN` **survives `execve`** (only a function handler resets to
default), so without an explicit `signal(SIGPIPE, SIG_DFL)` in the child
right after `fork` and before `exec`, the spawned program — and anything
*it* spawns — silently inherits the ignore. Surfaced as GNU `yes` printing an
unexpected "Broken pipe" diagnostic to a captured stderr stream instead of
dying normally. Generalizes: **any parent-side signal-disposition change for
the harness's own benefit must be undone in the child before exec**, not just
assumed to reset.

**Validation technique when there's no MSVC:** copy the test `.cpp` under
test, append a throwaway `int main()` that constructs the `TEST_CLASS` struct
and calls each `TEST_METHOD` directly, in the *same translation unit*. A
separate driver `.cpp` that only forward-declares the methods will link-fail
— GCC does not emit an inline-in-class member function's body into an object
file unless something in *that same TU* odr-uses it, and the real
`CppUnitTestFramework`'s macros normally do that registration for you; the
`/tmp` shim doesn't. Confirmed via `nm`: a separate-TU driver produced an
`EndToEndTests.o` with zero of the five test symbols, at both `-O0` and
`-O2`.

Related: [[console-layer-platform-seam]], [[no-msvc-in-agent-runner]],
[[cppunittest-shim-gotchas]] (Test Engineer's memory — same shim, same file).

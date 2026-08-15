---
name: rtvm-004-prompt-abort-nonblocking-stdin
description: How the RTVM-004..008/404/501..503 prompt-and-abort mechanism was built on issue #17 — the fourth StdinChannel seam function, the prompt-schedule anchoring, and why select() with a zero timeout stands in for Win32's four availability tests
metadata:
  type: project
---

Implemented 2026-08-14 on issue #17, fully specified by `docs/SDD.md` §1.2/
§1.3/§2.8 — no design decisions were mine to make here, only the POSIX
mirror of the Win32 table.

**`StdinChannel` gained a fourth seam function, `tryNonBlockingRead`,**
alongside the three from [[console-layer-platform-seam]]. One non-blocking
read attempt, dispatched on `StdinKind`, returning `NoDataAvailable` /
`DataRead` / `Eof`. `tryReadLine` calls it at most once per invocation, then
re-checks the buffer for a complete line — never loops on it, never waits.

**POSIX mirror trick worth remembering:** a zero-timeout `select()` on the
fd gives the *same* readiness semantics as the Win32 per-kind table without
needing to special-case Console vs. Pipe on Linux. Against a canonical-mode
tty, the kernel's line discipline only reports "readable" once a full line
(Enter) has been buffered — exactly the property Windows gets from peeking
for a `VK_RETURN` key-down record before calling `ReadConsoleA`. Against a
pipe, `select()` reports readable as soon as *any* byte has arrived, which
matches `PeekNamedPipe`'s byte-count test (no line-completeness requirement
there — RTVM-005 doesn't require it either, since the stop response is
still just "a line", not "the pipe's next full line only"). A regular file
skips the readiness check entirely on both platforms, since a disk read
never blocks indefinitely either way. This is why one `tryNonBlockingRead`
POSIX branch can cover three of the four `StdinKind` values with one
mechanism, while the Win32 branch genuinely needs three separate API calls.

**Prompt scheduling is anchored to the nominal 15s/25s/35s.. sequence, not
to when a poll happened to notice the deadline had passed** — `m_nextPromptAt
+= kPromptInterval` (a fixed add), not `elapsed + kPromptInterval` (which
would drift the schedule forward by however late the poll happened to be).
Given the poll interval is every 1024 search nodes (microseconds), this
distinction is invisible in practice, but it is what TP-502's "each within
±1.0 s of *nominal*" actually needs if a solve is ever slow per node.

**`isStopResponse`'s two spec clauses ("first non-whitespace char is s/S" OR
"trimmed content case-insensitively equals stop") are logically the same
check** — every spelling of "stop" starts with 's' or 'S', so implementing
only the first-character rule satisfies both. Don't be tempted to write two
separate branches; there's no case that distinguishes them.

**Verification was end-to-end by hand, not unit tests** — RTVM-004..008
(UI), RTVM-404 (OUT) and RTVM-501..503 (NFR) are all process-level per
[[output-layer-scope-per-issue]] (`docs/SDD.md` §3.3 lists TP-001..009,
TP-401..406, TP-500..507 as the end-to-end lane). Built a real g++ binary
and drove it with the RTVM-507 hook: a named pipe (FIFO) exercises the
`Pipe` `StdinKind` branch end to end (peek → read → line-complete), a
regular file with trailing content after the puzzle exercises `File` and
the shared-buffer continuity from [[blocking-is-allowed-before-the-solve]]
(stop response sitting in the file is seen on the very first poll, well
before 15 s — correct, since RTVM-005 isn't gated on a prompt having fired),
and `< /dev/null` exercises `Null`/RTVM-008. Measured: exactly 5 prompts at
15/25/35/45/55 s over a 60 s hook run with strictly increasing step counts;
abort-to-exit latency ~20-30 ms over a pipe; unanswered-prompt lapse
finishes under 20 s (TP-007's own bound). `Console`/tty could not be
exercised (no pty in this harness) — flagged for the Test Engineer, who
also can't get one without a real Windows console attached, so this stays
inherently hard to automate on both sides.

**One exception to "no unit tests for process-level TPs": `Reporter`'s
Aborted branch.** Followed the precedent RTVM-403 already set in
`ReporterTests.cpp` (streams taken by reference → directly testable with
`std::ostringstream`, no process needed) and added
`rtvm404_abortedReportsAbandonmentMessageOffStdout`. `SolveSession` itself
does *not* get this treatment — unlike `Reporter`, it isn't pure: `onPoll`
touches real wall-clock time and a concrete `StdinChannel` tied to an OS
handle, so it doesn't have the "swap in a fake and test directly" property
`Reporter` does. Also confirmed by reasoning through MSVC's function-level
linking: had I added `SolveSession.cpp` to the test project without also
adding `StdinChannel.cpp`, a Debug link (where `/OPT:REF` is typically off)
would fail on an unresolved `StdinChannel::tryReadLine` referenced from
`onPoll`'s object code even though no test calls `onPoll` — not worth the
churn for one static helper (`isStopResponse`) already covered thoroughly
by the manual runs above.

Related: [[console-layer-platform-seam]], [[blocking-is-allowed-before-the-solve]],
[[output-layer-scope-per-issue]], [[msvc-cppunittest-crt]],
[[no-msvc-in-agent-runner]]

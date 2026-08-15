---
name: rtvm-405-406-aggregate-conformance
description: Issue #18 — RTVM-405/RTVM-406 exit-code mapping and stdout purity were already fully implemented by earlier issues; the actual deliverable was the missing aggregate test tying all five outcomes together, plus recognising the process-level half was already scripted elsewhere.
metadata:
  type: project
---

Implemented 2026-08-15 on issue #18. `docs/RTVM.md` §9.8.4 already says this
explicitly: `Reporter`/`main.cpp` carried the whole RTVM-405 mapping and the
RTVM-406 stream table since #10/#11/#12/#17, but none of those issues
credited RTVM-401/402/403/405/406 — "exit code and wording are separate
clauses of separate procedures, and #18 owns TP-405 as a whole." That's a
useful shape to recognise on sight: an aggregate requirement (RTVM-405/406
are explicitly *aggregate* — "across every reachable outcome") can be true
in every individual case for several issues running and still have **no
test that proves the aggregate**, because each prior issue only tested its
own one outcome (TP-403 tested `InvalidInput`, TP-404 tested `Aborted`).

**What actually shipped:** one new `TEST_METHOD` in `ReporterTests.cpp`
(`rtvm405and406_exitCodeAndStdoutPurityAcrossAllFiveOutcomeClasses`) that
drives real `parseGrid`/`solve()` for four fixture classes plus the
`SolveReport::aborted()` factory for the fifth (same substitution
[[rtvm-004-prompt-abort-nonblocking-stdin]] already established — `Reporter`
takes streams by reference, so this needs no process spawn), and checks all
three RTVM-405/406/TP-300 clauses — exit codes `0,0,1,2,3`, no forbidden
substring on stdout, five pairwise-distinct outcomes — as one aggregate over
all five runs, not five separate assertions.

**What was correctly left alone:** `tests/windows/run-procedures.ps1`
(written at #23, not by the Software Engineer) already has TP-405/TP-406
sections driving four of five fixture classes as real process runs with
real OS exit codes — the genuine process-level half neither this test nor
any g++ unit test can reach. Its `Aborted` case is `NOT-RUN`, gated on the
same "no interactive stop-response driver yet" limitation TP-004..008
already carry from #17. Don't try to close that from the Software Engineer
side — it's a test-harness capability question, not a product code gap, and
conflating the two would be scope the issue didn't ask for.

**Verification pattern used:** the usual [[no-msvc-in-agent-runner]] shim run
(67/67 full, 49/49 core-only, up from 63 pre-existing), plus something extra
worth repeating when an issue is really about output/exit-code conformance —
built the real `src/SudokuCore + src/SudokuSolver` g++ binary directly (no
shim) and ran it against three of the shipped `samples/*.txt` fixtures,
diffing exit code and byte counts against what RTVM-405/406 require. Cheap,
and it's evidence the unit test's stand-in pipeline (`gridFromCompactForm` +
`solve()` + `Reporter`, skipping `CommandLine`/`InputSource`/`argv`) matches
what the real end-to-end binary does.

Related: [[rtvm-004-prompt-abort-nonblocking-stdin]],
[[output-layer-scope-per-issue]], [[no-msvc-in-agent-runner]]

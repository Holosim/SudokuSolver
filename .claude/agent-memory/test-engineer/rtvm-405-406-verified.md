---
name: rtvm-405-406-verified
description: RTVM-405/406 (exit-code mapping, stdout/stderr purity) PASS on issue #18 — how I independently re-derived it beyond the unit test, and the TP-405/TP-505 scope line worth remembering.
metadata:
  type: project
---

2026-08-15, issue #18, branch `issue-18`: **PASS**, first verification of
RTVM-405/RTVM-406 as the aggregate assertions they are (over all five
`Outcome`s, not any one path). Software Engineer's commit `79b30bb` added
`rtvm405and406_exitCodeAndStdoutPurityAcrossAllFiveOutcomeClasses` to
`ReporterTests.cpp`; `Reporter.cpp`/`main.cpp` themselves were untouched —
the exit-code mapping and stream assignment had already landed incrementally
across #10/#11/#12/#17.

**Beyond re-running the unit driver** (full 67/67, core-only 49/49, matching
the hand-off's counts — see [[generated-test-driver]]), I independently:
- built the real console binary (g++, no shim) and ran it against
  `samples/easy|nonunique|malformed|unsolvable.txt`, checking the actual OS
  exit code and byte counts on both streams, per
  [[false-pass-from-unchecked-exit-codes]] — a unit test using
  `std::ostringstream` in place of `std::cout`/`std::cerr` proves the
  `Reporter` logic but not that `main`'s `static_cast<int>(run(...))`
  actually reaches the process exit code; the real-binary run is what closes
  that gap.
- grepped `Messages.cpp` for every string it can produce and checked each
  against `docs/SDD.md` §2.8's message→stream table by hand — the issue's
  own "design pointers" section framed an undocumented message as the
  finding this issue existed to catch. None found; worth repeating this
  cross-check on any future issue that touches `Reporter`/`Messages`.

**Scope line worth remembering:** TP-405 as written has two clauses — the
five-fixture-class exit codes (this issue's scope) *and* "additionally run
the full TP-505 input corpus and assert every exit code is in `{0,1,2,3}`".
The second clause belongs to RTVM-505 (still `Approved`, no owning issue
yet), not RTVM-405/406 — #18's own issue body only lists TP-405/TP-406/
TP-300's whole-run half as its procedures. Don't fold TP-505's corpus run
into a PASS for this issue; it isn't this issue's to close.

RTVM-405/406 rows were still `Approved` with no commit at hand-off time —
that's expected here, not a gap: this project's convention is the Systems
Engineer sets `In Test`/commit-hash on RTVM promotion, not the Software
Engineer's implementing commit. See [[rtvm-500-verified]] and siblings for
the same pattern on other requirement rows.

# Requirements Traceability & Verification Matrix (RTVM)

<!--
Owned by the Systems Engineer. Don't enter line items against a
[PROPOSED] item in docs/PROJECT_DEFINITION.md — wait for it to become
[CONFIRMED]. See systems-engineer.md for the escalation and handoff
rules this document participates in.
-->

> **Source of truth:** `docs/PROJECT_DEFINITION.md` at commit `109d644`.
> Every item in that document is `[CONFIRMED]`, so every line item below is
> written against confirmed scope. Where this document had to sharpen a
> confirmed decision to make it testable, that sharpening is recorded
> explicitly in §7 Interpretations — nothing is silently assumed.

## ID scheme

The category blocks below are a starting point — adjust them to fit
the project, not a fixed requirement:

| Category | Prefix | Range |
| --- | --- | --- |
| UI | UI | 001–099 |
| Data in | DATA-IN | 100–199 |
| Core algorithm / processing | CORE | 200–299 |
| Data out | DATA-OUT | 300–399 |
| Output | OUT | 400–499 |
| Non-functional | NFR | 500–599 |
| Deliverable | DELIV | 900–999 |

Companion schemes: `SN-<n>` for stakeholder needs (defined in
`docs/PROJECT_DEFINITION.md`), `TP-<nnn>` for test procedures.

Every requirement `RTVM-<nnn>` has exactly one test procedure `TP-<nnn>`
carrying the same number. `RTVM-200` is verified by `TP-200`. Issues,
commits, and test reports all cite the `RTVM-<nnn>` form.

## Verification vocabulary

Test / Demonstration / Analysis / Inspection. `DELIV` items are
typically verified by inspection and specified in `docs/SDD.md`'s
build/toolchain conventions rather than by a runtime test.

## Status vocabulary

Draft → Approved → In Implementation → In Test → Verified, plus
Blocked / Withdrawn.

## Requirements

| Req ID | Requirement | Stakeholder Need(s) | Verification Method | Status | Commit(s) |
| --- | --- | --- | --- | --- | --- |
| **UI — user interface (§4.1, §4.4)** | | | | | |
| RTVM-001 | On launch the application begins solving immediately. It presents no menu, no mode selection, and asks the user nothing before reading the puzzle. | SN-1, SN-6 | Test (TP-001) | Approved | |
| RTVM-002 | If a first command-line argument is present it is treated as a path to a puzzle file, and the puzzle is read from that file. Any further arguments are ignored. | SN-1, SN-8 | Test (TP-002) | Approved | |
| RTVM-003 | If no command-line argument is present the puzzle is read from standard input. | SN-1, SN-8 | Test (TP-003) | Approved | |
| RTVM-004 | While a solve is still running at a prompt point (RTVM-501/502) the application writes a progress prompt to stderr stating (a) that it is still working, (b) the whole seconds elapsed, (c) how to stop, and (d) that no response is required. | SN-5 | Test (TP-004) | Approved | |
| RTVM-005 | If the user gives the documented stop response at any prompt, the application stops the solve, reports that it was abandoned at the user's request, and exits with code `3`. | SN-5 | Test (TP-005) | Approved | |
| RTVM-006 | No prompt requires a response. The application never blocks on reading a prompt reply: continuing is the default and an unanswered prompt simply lapses at the next prompt point. | SN-5, SN-8 | Test (TP-006) | Approved | |
| RTVM-007 | If the solve finishes while a prompt is outstanding, the result is printed and the application exits normally. It does not wait for a reply to the lapsed prompt. | SN-5 | Test (TP-007) | Approved | |
| RTVM-008 | An invocation with no interactive console (stdin redirected from a file or pipe, stdout/stderr redirected) is never blocked or delayed by the prompt mechanism, and always terminates with a result and an exit code. | SN-5, SN-8 | Test (TP-008) | Approved | |
| RTVM-009 | A file argument that cannot be opened or read is reported as a specific diagnostic naming the path and the reason, and exits with code `1`. | SN-4, SN-8 | Test (TP-009) | Approved | |
| **DATA-IN — internal representation of input (§4.2)** | | | | | |
| RTVM-100 | The application parses 9 lines of 9 characters into an internal 9×9 grid in which each cell holds either a given digit 1–9 or "empty". | SN-1, SN-2 | Test (TP-100) | Approved | |
| RTVM-101 | Both `0` and `.` denote an empty cell, interchangeably, including mixed within the same puzzle. | SN-1 | Test (TP-101) | Approved | |
| RTVM-102 | Input whose shape is wrong — fewer than 9 lines, or any of the first 9 lines not exactly 9 characters after the rules of RTVM-106 are applied — is rejected as malformed with a message naming the offending line number and what was wrong with it. | SN-4 | Test (TP-102) | Approved | |
| RTVM-103 | Input containing a character other than `1`–`9`, `0` or `.` in the grid is rejected as malformed with a message naming the offending character and its row and column. | SN-4 | Test (TP-103) | Approved | |
| RTVM-104 | Input that is well-formed but self-contradictory — the same digit given twice in a row, a column, or a 3×3 box — is rejected with a message naming the digit, the unit, and both conflicting cells. | SN-4 | Test (TP-104) | Approved | |
| RTVM-105 | Validation reports exactly one fault, the first found, in the fixed precedence order: shape (RTVM-102) → illegal character (RTVM-103) → contradiction (RTVM-104). Cells are named in one-based `r<row>c<col>` form. A rejected puzzle is never passed to the solver. | SN-4 | Test (TP-105) | Approved | |
| RTVM-106 | Input is accepted with either LF or CRLF line endings and with or without a trailing newline. Leading and trailing horizontal whitespace on a line is ignored; interior whitespace is an illegal character. Content after the ninth line is ignored. | SN-1, SN-8 | Test (TP-106) | Approved | |
| **CORE — solver (§4.4, §4.5, §5)** | | | | | |
| RTVM-200 | Given a valid, uniquely-solvable standard 9×9 puzzle, the solver produces the grid's unique solution: all 81 cells filled with 1–9, with no digit repeated in any row, column, or 3×3 box, and every given preserved in place. | SN-2 | Test (TP-200) | Approved | |
| RTVM-201 | Given a well-formed, non-contradictory puzzle that admits no completion, the solver reports "no solution" and terminates. It does not loop, guess indefinitely, or emit a partial grid. | SN-2, SN-4 | Test (TP-201) | Approved | |
| RTVM-202 | The solver determines whether a puzzle has more than one solution by searching for at most two solutions and stopping. Where two are found it yields the first found together with a "not unique" indication. It does not enumerate or count all solutions. | SN-2, SN-3 | Test (TP-202) | Approved | |
| RTVM-203 | The solve is cooperatively interruptible: once an abort is requested the solver stops and yields the "aborted" outcome within 1.0 s, leaving the process free to exit cleanly. | SN-5 | Test (TP-203) | Approved | |
| RTVM-204 | The solver maintains a monotonically increasing count of search steps taken, readable by the rest of the application and by the test suite while the solve is in flight. This is what makes "the solve is still making progress" (§7 acceptance #6) an observable fact rather than an assertion. | SN-5 | Test (TP-204) | Approved | |
| **DATA-OUT — internal representation of output (§4.1, §4.3)** | | | | | |
| RTVM-300 | Every run produces exactly one outcome drawn from the closed set: `Solved`, `SolvedNotUnique`, `InvalidInput`, `NoSolution`, `Aborted`. There is no run that produces none and no run that produces two. | SN-3, SN-4, SN-8 | Test (TP-300) | Approved | |
| RTVM-301 | The `Solved` and `SolvedNotUnique` outcomes carry a complete 9×9 grid of digits 1–9 with no empty cell. | SN-3 | Test (TP-301) | Approved | |
| RTVM-302 | The `InvalidInput` outcome carries structured fault detail (fault kind, line/row/column, digit or character involved) rather than a pre-formatted message, so that all wording lives in the output layer. | SN-4, SN-7 | Test (TP-302) | Approved | |
| **OUT — presentation (§4.1, §4.3)** | | | | | |
| RTVM-400 | A solved grid is written to stdout pretty-printed with box separators, in exactly the 13-line ASCII format given in §6.2. | SN-3 | Test (TP-400) | Approved | |
| RTVM-401 | For the `SolvedNotUnique` outcome the grid is followed on stdout by a statement that the solution shown is not unique. | SN-3 | Test (TP-401) | Approved | |
| RTVM-402 | For the `NoSolution` outcome a plain statement that the puzzle has no solution is written to stdout, and no grid is written. | SN-3, SN-4 | Test (TP-402) | Approved | |
| RTVM-403 | For the `InvalidInput` outcome a specific human-readable diagnostic naming the fault is written to **stderr**, and nothing is written to stdout. | SN-4 | Test (TP-403) | Approved | |
| RTVM-404 | For the `Aborted` outcome a message stating the solve was abandoned at the user's request is written to **stderr**, and nothing is written to stdout. | SN-5 | Test (TP-404) | Approved | |
| RTVM-405 | The process exit code is `0` for `Solved` and `SolvedNotUnique`, `1` for `InvalidInput`, `2` for `NoSolution`, `3` for `Aborted`, with no other exit code reachable. | SN-8, SN-4 | Test (TP-405) | Approved | |
| RTVM-406 | Across every reachable outcome, stdout carries only the result (grid, non-unique note, no-solution statement). No prompt text, no diagnostic, and no progress output ever reaches stdout. | SN-8 | Test (TP-406) | Approved | |
| **NFR — non-functional (§4.4, §5)** | | | | | |
| RTVM-500 | Any standard 9×9 puzzle, including a hard 17-clue grid, is solved in under 10 s wall clock on a typical desktop (reference machine defined in §6.3). | SN-5 | Test (TP-500) | Approved | |
| RTVM-501 | The first progress prompt is emitted when the solve has been running for 15 s, within a tolerance of ±1.0 s. | SN-5 | Test (TP-501) | Approved | |
| RTVM-502 | Progress prompts repeat every 10 s thereafter — at 25 s, 35 s, 45 s and so on — each within ±1.0 s of its nominal time, for as long as the solve is running. | SN-5 | Test (TP-502) | Approved | |
| RTVM-503 | The solve does not pause while a prompt is displayed or while a reply is awaited: the RTVM-204 search-step count strictly increases across every prompt window. | SN-5 | Test (TP-503) | Approved | |
| RTVM-504 | The application is never silent while working. From launch to exit the user always has either a result, a diagnostic, or a prompt. The longest permitted interval with no output on either stream is bounded by the RTVM-501 first-prompt threshold **before** the first prompt (15 s + 1.0 s tolerance = 16.0 s) and by the RTVM-502 repeat interval **thereafter** (10 s + 1.0 s tolerance = 11.0 s). See §7 I-12. | SN-5 | Test (TP-504) | Approved | |
| RTVM-505 | No input causes an unhandled exception, an access violation, an assertion dialog, or a non-zero exit code outside the set in RTVM-405. Every run terminates. | SN-4 | Test (TP-505) | Approved | |
| RTVM-506 | The delivered executable is a self-contained x64 Windows console application that runs on a clean Windows machine with no installed runtime or third-party component beyond what a stock Windows install provides. | SN-6, SN-7 | Test (TP-506) | In Implementation | |
| RTVM-507 | The build provides a documented diagnostic means of forcing a solve to run past the prompt thresholds without altering ordinary behaviour, so that RTVM-004…008 and RTVM-501…504 are verifiable end-to-end. It is documented in `docs/SDD.md`, not in the user-facing README, and is inert in normal use. | SN-5 | Test (TP-507) | Approved | |
| **DELIV — deliverable requirements (§6). Verified by inspection.** | | | | | |
| RTVM-900 | The repository contains a committed, openable Visual Studio 2022 solution and project file(s) — not source files alone. (D-1) | SN-7 | Inspection (TP-900) | In Test | |
| RTVM-901 | A client engineer can clone, open, build, and run the solution in VS 2022 with no setup step that is not written down in the README. (D-2) | SN-7 | Inspection (TP-901) | In Implementation | |
| RTVM-902 | The solution builds with the stock VS 2022 toolchain and the C++ standard library alone. No third-party library, package manager, or downloaded dependency of any kind. (D-3) | SN-7 | Inspection (TP-902) | In Test | |
| RTVM-903 | The solver core is a separate compilation unit / module from the console I/O layer and has no dependency on stdin, stdout, stderr, or command-line parsing. The grid dimension appears as a single named constant, not as literal `9`s scattered through the code. (D-4) | SN-7 | Inspection (TP-903) | In Test | |
| RTVM-904 | The repository carries a README covering how to build, how to run, and the puzzle input format. (D-5) | SN-7 | Inspection (TP-904) | In Implementation | |
| RTVM-905 | Automated tests are part of the delivered solution and are runnable by the client through a documented command or VS action. (D-6) | SN-7 | Inspection (TP-905) | In Implementation | |
| RTVM-906 | The solution targets C++17 and x64, and is a Visual Studio solution only — the repository contains no CMake or other cross-platform build files. (D-7) | SN-7 | Inspection (TP-906) | In Test | |
| RTVM-907 | Five sample puzzles ship with the solution and are referenced from the README: easy, hard 17-clue, unsolvable, malformed, and non-unique. (§4.2) | SN-1, SN-7 | Inspection (TP-907) | In Test | |

## Test Procedures

<!-- TP-<nnn>, one per verifiable requirement, with concrete test
     input values and expected output — not just "it works." -->

All fixtures referenced below are defined literally in §6.1. Unless a
procedure says otherwise:

- The application under test is the x64 Release build.
- stdout and stderr are captured **separately**; a procedure that says
  "stdout is empty" means empty, not "contains only the expected text".
- Grid comparisons normalise line endings (a Windows text-mode build
  emits CRLF; the fixtures in §6.1 are written with LF).
- "exit code" is the process exit code as reported by the shell
  (`%ERRORLEVEL%` / `$LASTEXITCODE`).

### UI

**TP-001 — no menu, immediate solve.** Run with `P-EASY` on stdin.
Expect: the entire stdout is the §6.2 grid for `S-EASY` and nothing
else; stderr contains no question, no menu, and no "press any key"
text; exit code `0`. Repeat with the file-argument form to confirm the
absence of a menu is not input-source dependent.

**TP-002 — file argument.** Write `P-EASY` to `easy.txt`. Run
`SudokuSolver.exe easy.txt` with stdin closed. Expect stdout = `S-EASY`
grid, exit `0`. Then run `SudokuSolver.exe easy.txt ignored extra args`
— expect identical output and exit code, proving trailing arguments are
ignored. Then run `SudokuSolver.exe easy.txt < unsolvable.txt` —
expect the *file* to win: stdout = `S-EASY` grid, exit `0`.

**TP-003 — stdin fallback.** Run `SudokuSolver.exe` with no arguments
and `P-EASY` piped to stdin. Expect stdout = `S-EASY` grid, exit `0`.

**TP-004 — prompt content and destination.** Run with the RTVM-507
long-solve hook active, capturing stderr separately. At the first
prompt, expect a line on **stderr** that matches
`Still working \(\d+s elapsed\)\.` and additionally contains, case
insensitively, a description of the stop gesture and the phrase
indicating no response is needed. Expect **nothing** on stdout at that
moment. Reference wording (SDD may pin the stop gesture):
`Still working (15s elapsed). Type s then Enter to stop; no response needed - the solve continues.`

**TP-005 — abort.** Run with the long-solve hook active. At the first
prompt, send the documented stop response. Expect: stderr gains a line
containing `abandoned at` the user's request; stdout is empty; exit
code `3`; the process terminates within 1.0 s of the response
(RTVM-203).

**TP-006 — no response required.** Run with the long-solve hook active
and an interactive-equivalent stdin that is held open but never
written to. Expect prompts at 15 s, 25 s, 35 s and 45 s; the process
still running and still emitting prompts after 45 s; and, **after the
first prompt**, no point at which output stops for longer than 11.0 s
(§7 I-12). Then send the stop response and
confirm exit `3`. Verifies the process never sat blocked on a read.

**TP-007 — lapsed prompt abandoned.** Configure the long-solve hook to
complete the solve at approximately 18 s — three seconds after the
first prompt, with that prompt unanswered. Expect: the `S-EASY` grid on
stdout within 1.0 s of solve completion, exit `0`, and no further
prompt at 25 s. The measured wall clock from launch to exit must be
under 20 s, proving the program did not wait on the lapsed prompt.

**TP-008 — non-interactive invocation.** Run
`SudokuSolver.exe < hard17.txt > out.txt 2> err.txt` from a script with
no console attached to stdin. Expect exit `0`, `out.txt` = `S-HARD17`
grid, `err.txt` empty. Repeat with the long-solve hook active and stdin
redirected from `NUL`: expect prompts to appear in `err.txt` on
schedule, the process never to block, and the run to terminate with a
result and an exit code without any input being supplied.

**TP-009 — unreadable file argument.** Run
`SudokuSolver.exe does_not_exist.txt`. Expect: stdout empty; stderr
names the path `does_not_exist.txt` and states it could not be opened;
exit code `1`. Repeat with a path that is an existing **directory** —
same expectation.

### DATA-IN

**TP-100 — parse.** Unit test: parse `P-EASY`. Expect a 9×9 structure
with exactly 30 given cells, cell `r1c1` = 5, `r1c2` = 3, `r1c3` =
empty, `r9c9` = 9, `r5c1` = 4. Round-tripping the parsed grid back to
the 81-character form reproduces `P-EASY` with `0` as the empty
character.

**TP-101 — `0` and `.` interchangeable.** Parse `P-EASY` (all `0`),
`P-EASY-DOTS` (all `.`), and `P-EASY-MIXED` (rows 1–4 use `0`, rows 5–9
use `.`). Expect all three to parse to an identical grid, and all three
run end-to-end to the `S-EASY` grid with exit `0`.

**TP-102 — malformed shape.** Three cases, each expecting stdout empty
and exit `1`:
1. `P-SHORT` (8 lines) — stderr names line 9 as missing / input ended early.
2. `P-LONGLINE` (line 5 is `40080300111`, 11 characters) — stderr names line 5 and its length.
3. `P-SHORTLINE` (line 5 is `4008030`, 7 characters) — stderr names line 5 and its length.

**TP-103 — illegal character.** Run `P-BADCHAR`, which is `P-EASY` with
`r1c1` replaced by `X`. Expect stdout empty, exit `1`, and stderr
naming both the character `X` and the position `r1c1`.

**TP-104 — contradictory givens.** Three cases, each expecting stdout
empty, exit `1`, and a stderr message naming the digit, the unit, and
both cells:
1. `P-CONTRA-ROW` — line 1 is `530070500`; digit `5` twice in row 1, at `r1c1` and `r1c7`.
2. `P-CONTRA-COL` — line 1 is `430070000`; digit `4` twice in column 1, at `r1c1` and `r5c1`.
3. `P-CONTRA-BOX` — line 1 is `580070000`; digit `8` twice in the top-left box, at `r1c2` and `r3c3`.

Each of these three has been machine-verified to contain **exactly one**
conflict of exactly the named kind, so the expected message is
unambiguous regardless of the order in which the implementation checks
rows, columns, and boxes.

**TP-105 — fault precedence and single-fault reporting.** Run
`P-MULTIFAULT` — `P-EASY` with line 1 replaced by `X30070300` and line 9
removed, so it carries all three fault kinds at once (8 lines; an `X` at
`r1c1`; digit `3` twice in row 1 at `r1c2` and `r1c7`). Expect stderr to
report the **shape** fault only — exactly one fault line — and exit `1`.
Then run `P-MULTIFAULT-9`, the same line 1 with all 9 lines present:
expect the **illegal character** fault only, not the row duplicate.
Confirm by instrumentation or log that the solver was never entered in
either case.

**TP-106 — line endings and whitespace.** Five cases, all expecting the
`S-EASY` grid on stdout and exit `0`:
1. `P-EASY` with CRLF endings.
2. `P-EASY` with LF endings.
3. `P-EASY` with no trailing newline on line 9.
4. `P-EASY` with two trailing blank lines after line 9, and a 10th line reading `garbage` — ignored.
5. `P-EASY` with three leading spaces and two trailing spaces on line 3.

Plus one negative case: `P-EASY` with line 3 as `098 000060` (interior
space) — expect exit `1` and stderr naming the space as an illegal
character at `r3c4`.

### CORE

**TP-200 — correct solve.** Solve `P-EASY` and `P-HARD17`. Expect
exactly `S-EASY` and `S-HARD17` respectively (§6.1). For each result,
assert programmatically: 81 cells all in 1–9; every row, column, and
3×3 box is a permutation of 1–9; every given in the input appears
unchanged at the same position.

**TP-201 — no solution.** Solve `P-UNSOLVABLE` (§6.1 — `P-EASY` with
`r1c3` set to `1`; the givens are mutually consistent, so this is *not*
caught by RTVM-104, and the solver must be the thing that discovers it).
Expect outcome `NoSolution` within the RTVM-500 budget, no grid, exit
`2`.

**TP-202 — non-uniqueness.** Solve `P-NONUNIQUE` (§6.1), which has
exactly two solutions, `S-NONUNIQUE-A` and `S-NONUNIQUE-B`, differing
only in cells `r4c6`, `r4c9`, `r5c6`, `r5c9`. Expect the outcome
`SolvedNotUnique`, and the printed grid to equal **either** `A` **or**
`B` — the procedure must not assert which, since that depends on search
order. Also assert via instrumentation that the solver stopped after
finding the second solution and did not continue searching. Control
case: solve `P-EASY`, expect outcome `Solved` (not `SolvedNotUnique`).

**TP-203 — interruptibility latency.** Unit test the solver directly:
start a solve on the RTVM-507 long-running workload, wait 2 s, request
abort, and measure the interval until the solver returns. Expect
< 1.0 s over 10 consecutive repetitions, worst case reported.

**TP-204 — progress counter.** Unit test: start a solve on the
RTVM-507 long-running workload. Sample the search-step count at 1 s
intervals for 10 s. Expect 10 strictly increasing samples, and the
first sample > 0.

### DATA-OUT

**TP-300 — closed outcome set.** Drive the application once for each
of the five fixture classes — `P-EASY` (`Solved`), `P-NONUNIQUE`
(`SolvedNotUnique`), `P-BADCHAR` (`InvalidInput`), `P-UNSOLVABLE`
(`NoSolution`), long-solve hook + stop response (`Aborted`). Expect
each run to report exactly one outcome and for the five to be
distinct. Unit test the outcome type to confirm it cannot represent
"none" or two at once.

**TP-301 — solved-grid representation.** Unit test: for the `Solved`
result of `P-EASY` and the `SolvedNotUnique` result of `P-NONUNIQUE`,
assert all 81 cells are in 1–9 and none is the "empty" value.

**TP-302 — structured fault detail.** Unit test: parse `P-CONTRA-ROW`
and inspect the returned fault object. Expect fields identifying the
kind (`RowDuplicate`), the digit (`5`), and the two cells
(`r1c1`, `r1c7`) as data. Assert the object contains no pre-formatted
English sentence — the same fault object, passed to the output layer,
is what produces the TP-104 message.

### OUT

**TP-400 — grid format.** Run `P-EASY`. Expect stdout to equal, byte
for byte after line-ending normalisation, the 13-line block in §6.2 for
`S-EASY`. Assert: 13 lines; lines 1, 5, 9, 13 are exactly
`+-------+-------+-------+`; every other line is exactly 25 characters
and matches `^\| \d \d \d \| \d \d \d \| \d \d \d \|$`; the output is
pure ASCII, with no character above U+007F.

**TP-401 — non-unique note.** Run `P-NONUNIQUE`. Expect stdout to be
the 13-line grid followed by a line stating the solution is not unique.
Reference wording:
`Note: this puzzle has more than one solution; the solution shown is the first one found.`
Expect stderr empty and exit `0`.

**TP-402 — no-solution statement.** Run `P-UNSOLVABLE`. Expect stdout
to be a single line stating the puzzle has no solution — reference
wording `This puzzle has no solution.` — with no grid and no separator
line. Expect exit `2`.

**TP-403 — invalid-input diagnostic stream.** Run `P-BADCHAR`,
`P-SHORT`, and `P-CONTRA-ROW`. For each: assert stdout is byte-empty
(zero bytes, not "just whitespace") and the diagnostic appears on
stderr. Exit `1` in all three cases.

**TP-404 — abort message stream.** Run with the long-solve hook and
send the stop response. Assert stdout is byte-empty and stderr contains
the abandonment message. Exit `3`.

**TP-405 — exit codes.** Run the five fixture classes of TP-300 and
assert exit codes `0`, `0`, `1`, `2`, `3` respectively. Additionally
run the full TP-505 input corpus and assert every observed exit code is
in `{0, 1, 2, 3}`.

**TP-406 — stream separation.** For every run in TP-405, capture stdout
to a file and assert its contents consist only of: the 13-line grid,
optionally the non-unique note, or the no-solution line, or nothing.
Assert stdout contains none of the substrings `Still working`,
`abandoned`, `r1c1`, `Error`, `could not`. This is the ST-4 guarantee —
a scripted caller capturing stdout is never handed text it must filter.

### NFR

**TP-500 — performance budget.** On the §6.3 reference machine, x64
Release build, no debugger attached: solve `P-HARD17` 10 consecutive
times, timing each run from process start to process exit. Expect the
**worst** of the 10 runs under 10.0 s. Report min / median / max.
Repeat for `P-EASY` and `P-UNSOLVABLE` — same 10.0 s ceiling applies to
each.

**TP-501 — first prompt timing.** Run with the long-solve hook, timing
from process start, timestamping each stderr line. Expect the first
prompt line at 15.0 s ±1.0 s. Repeat 5 times; all 5 within tolerance.

**TP-502 — repeat interval.** Same run as TP-501, extended to 60 s.
Expect prompt lines at 15, 25, 35, 45 and 55 s, each ±1.0 s of nominal,
and no prompt between them. Expect exactly 5 prompts in the window.

**TP-503 — solve continues during prompt.** Run with the long-solve
hook. For each prompt window — from the moment a prompt is emitted to
the moment the next one is — sample the RTVM-204 search-step count at
both ends. Expect the closing count strictly greater than the opening
count for every window, and expect that to hold identically whether a
reply is pending or not. This is §7 acceptance criterion 6.

**TP-504 — never silent.** Run each of `P-EASY`, `P-HARD17`,
`P-UNSOLVABLE`, `P-BADCHAR`, and the long-solve hook to 60 s.
Timestamp every byte written to either stream. Assert, for every run:

1. The interval from process start to the **first** byte of output on
   either stream is at most **16.0 s** (the RTVM-501 threshold plus its
   tolerance). For the four ordinary fixtures this is bounded far more
   tightly by RTVM-500; for the long-solve hook run it is the 15 s
   first prompt.
2. **After** the first byte of output, no interval with no output on
   either stream exceeds **11.0 s** (the RTVM-502 repeat interval plus
   its tolerance), up to process exit.

The two-part form is deliberate — see §7 I-12. A single 11.0 s bound
measured from process start would contradict RTVM-501, which requires
silence until 15 s.

**TP-505 — robustness corpus.** Run the application over a corpus of at
least 25 inputs and assert for each: process exits, exit code in
`{0,1,2,3}`, no crash dialog, no unhandled-exception text, non-zero
runtime under 60 s. Corpus includes at minimum: empty input (zero
bytes); a single newline; 81 dots (`P-BLANK`, a valid non-unique
puzzle); 10 000 lines of digits; a 1 MB single line; input containing a
NUL byte; input containing UTF-8 BOM; input containing non-ASCII
(`５３０...` full-width digits); binary content read from a `.exe`; all
fixtures in §6.1; and a file argument pointing at a directory, at a
zero-byte file, and at a locked file.

**TP-506 — self-contained executable.** Copy only the built
`SudokuSolver.exe` and the `samples/` directory to a clean Windows x64
machine with no Visual Studio, no redistributable, and no build tools
installed. Run `SudokuSolver.exe samples\easy.txt`. Expect the `S-EASY`
grid and exit `0`, with no missing-DLL dialog. Confirm with
`dumpbin /dependents` (run on the build machine) that the only imports
are stock Windows system DLLs.

**TP-507 — long-solve hook.** Inspect `docs/SDD.md` for the hook's
documentation and confirm it is *not* mentioned in the README.
Demonstrate: with the hook inactive, `P-HARD17` behaves exactly as in
TP-500 (no prompt, under 10 s). With it active, the solve runs past
60 s and every one of TP-501 to TP-504 is executable against it.
Confirm the hook cannot be triggered by any ordinary puzzle input.

### DELIV — inspection procedures

**TP-900.** Confirm the repository contains a `.sln` and at least one
`.vcxproj`, both tracked in git. Open the `.sln` in VS 2022 and confirm
it loads with no "project is unavailable" or migration prompt.

**TP-901.** On a machine that has never built this project: clone,
open the `.sln`, press Build. Confirm success with no step not written
in the README. Any manual step performed that is absent from the README
is a failure of this item.

**TP-902.** Inspect the project's include and library settings for any
path outside the repository, the Windows SDK, and the MSVC toolset.
Confirm no `packages.config`, no `vcpkg.json`, no `conanfile`, no
committed third-party source tree, and no NuGet references.

**TP-903.** Confirm by inspection that the solver's source files
contain no reference to `std::cin`, `std::cout`, `std::cerr`, `printf`,
`argv`, or any console API, and that they compile into a unit the test
project links against without the console layer. Grep the whole
codebase for the bare literal `9` used as a grid dimension — expect
zero occurrences outside the single named constant's definition.

**TP-904.** Confirm `README.md` contains a build section, a run section
with at least one worked example command and its output, and a
statement of the input format including that `0` and `.` are both
accepted.

**TP-905.** Confirm a test project is present in the solution and that
the README states how to run the tests. Execute that documented
command on a clean clone and confirm the suite runs and reports
pass/fail.

**TP-906.** Confirm the project's C++ Language Standard is set to
ISO C++17 and the only platform configured is x64. Confirm the
repository contains no `CMakeLists.txt`, no `Makefile`, and no
`meson.build`.

**TP-907.** Confirm `samples/` contains `easy.txt`, `hard17.txt`,
`unsolvable.txt`, `malformed.txt`, and `nonunique.txt`, that each
matches the corresponding §6.1 fixture byte for byte, and that the
README names all five and states the outcome each is expected to
produce.

## 6. Test data and reference definitions

### 6.1 Fixtures

Every puzzle below has been machine-verified for the property claimed.

`P-EASY` — valid, uniquely solvable (30 givens):

```
530070000
600195000
098000060
800060003
400803001
700020006
060000280
000419005
000080079
```

`S-EASY` — its unique solution:

```
534678912
672195348
198342567
859761423
426853791
713924856
961537284
287419635
345286179
```

`P-EASY-DOTS` — `P-EASY` with every `0` replaced by `.`.
`P-EASY-MIXED` — `P-EASY` with lines 1–4 using `0` and lines 5–9 using `.`.
Both solve to `S-EASY`.

`P-HARD17` — valid, uniquely solvable, 17 givens (the minimum possible
for a unique 9×9 puzzle; this is the performance reference):

```
000000010
400000000
020000000
000050407
008000300
001090000
300400200
050100000
000806000
```

`S-HARD17` — its unique solution:

```
693784512
487512936
125963874
932651487
568247391
741398625
319475268
856129743
274836159
```

`P-UNSOLVABLE` — `P-EASY` with `r1c3` set to `1`. The givens are
mutually consistent (no row, column, or box duplicate), so RTVM-104
must *not* reject it — the solver must discover it has no completion:

```
531070000
600195000
098000060
800060003
400803001
700020006
060000280
000419005
000080079
```

`P-NONUNIQUE` — exactly two solutions. Built from `S-EASY` by blanking
the deadly rectangle at `r4c6`, `r4c9`, `r5c6`, `r5c9`:

```
534678912
672195348
198342567
85976.42.
42685.79.
713924856
961537284
287419635
345286179
```

`S-NONUNIQUE-A` — `S-EASY` (row 4 `859761423`, row 5 `426853791`).
`S-NONUNIQUE-B` — as `S-EASY` but row 4 is `859763421` and row 5 is
`426851793`. The solver may print either; TP-202 accepts both.

`P-BLANK` — 9 lines of 9 `.` characters. A valid puzzle with an
enormous number of solutions; must produce `SolvedNotUnique` and exit
`0`, not hang.

Invalid fixtures:

| Fixture | Definition | Expected fault |
| --- | --- | --- |
| `P-SHORT` | `P-EASY` with line 9 removed (8 lines) | Shape — input ended after line 8 |
| `P-LONGLINE` | `P-EASY` with line 5 = `40080300111` | Shape — line 5 is 11 characters |
| `P-SHORTLINE` | `P-EASY` with line 5 = `4008030` | Shape — line 5 is 7 characters |
| `P-BADCHAR` | `P-EASY` with line 1 = `X30070000` | Illegal character `X` at `r1c1` |
| `P-CONTRA-ROW` | `P-EASY` with line 1 = `530070500` | Digit `5` twice in row 1 (`r1c1`, `r1c7`) |
| `P-CONTRA-COL` | `P-EASY` with line 1 = `430070000` | Digit `4` twice in column 1 (`r1c1`, `r5c1`) |
| `P-CONTRA-BOX` | `P-EASY` with line 1 = `580070000` | Digit `8` twice in top-left box (`r1c2`, `r3c3`) |
| `P-MULTIFAULT` | `P-EASY` with line 1 = `X30070300`, line 9 removed | Shape only — precedence per RTVM-105 |
| `P-MULTIFAULT-9` | `P-EASY` with line 1 = `X30070300`, all 9 lines | Illegal character only — precedence per RTVM-105 |

The three `P-CONTRA-*` fixtures each contain exactly one conflict, of
exactly one kind — machine-verified. This matters: a fixture with an
overlapping row *and* column duplicate would make the expected
diagnostic depend on the implementation's check order, and the test
would be unfalsifiable.

The five shipped samples (RTVM-907) are: `samples/easy.txt` = `P-EASY`,
`samples/hard17.txt` = `P-HARD17`, `samples/unsolvable.txt` =
`P-UNSOLVABLE`, `samples/malformed.txt` = `P-BADCHAR`,
`samples/nonunique.txt` = `P-NONUNIQUE`.

### 6.2 Normative output format

The solved grid is exactly 13 lines of exactly 25 ASCII characters.
For `S-EASY`:

```
+-------+-------+-------+
| 5 3 4 | 6 7 8 | 9 1 2 |
| 6 7 2 | 1 9 5 | 3 4 8 |
| 1 9 8 | 3 4 2 | 5 6 7 |
+-------+-------+-------+
| 8 5 9 | 7 6 1 | 4 2 3 |
| 4 2 6 | 8 5 3 | 7 9 1 |
| 7 1 3 | 9 2 4 | 8 5 6 |
+-------+-------+-------+
| 9 6 1 | 5 3 7 | 2 8 4 |
| 2 8 7 | 4 1 9 | 6 3 5 |
| 3 4 5 | 2 8 6 | 1 7 9 |
+-------+-------+-------+
```

ASCII only — no box-drawing characters. A Windows console under a
non-UTF-8 code page will render U+2500-range characters as mojibake,
which would break both legibility (SN-3) and byte-comparable testing.

Reference wordings (an implementation may reword; the test procedures
assert the required *elements*, not the exact sentence, except for the
grid itself which is byte-normative):

| Case | Stream | Wording |
| --- | --- | --- |
| Not unique | stdout | `Note: this puzzle has more than one solution; the solution shown is the first one found.` |
| No solution | stdout | `This puzzle has no solution.` |
| Aborted | stderr | `Solve abandoned at user request.` |
| Progress prompt | stderr | `Still working (15s elapsed). 1234567 steps taken. Type s then Enter to stop; no response needed - the solve continues.` |

The progress-prompt wording above is now **pinned by `docs/SDD.md` §2.8**.
The `N steps taken` sentence is the live RTVM-204 counter and is present
so that RTVM-503 ("the solve did not pause") is observable from stderr
alone, without instrumentation — TP-503's process-level half reads it
from consecutive prompt lines. The leading `Still working (Ns elapsed).`
sentence is unbroken, so TP-004's regex still matches as written.

### 6.3 Reference machine for RTVM-500

"A typical desktop" is pinned as: x64, 4 or more physical cores at
2.5 GHz or above, 8 GB RAM or more, Windows 10/11, running the Release
build with no debugger attached and no other significant load. The
GitHub-hosted `windows-latest` runner satisfies this and is the
default measurement environment; TP-500 reports the machine it ran on
alongside the timings.

## 7. Interpretations

Confirmed scope did not specify these at the level of precision a test
procedure needs. Each is a **requirements-level sharpening, not a scope
change** — recorded here so it is a decision on the record rather than
an assumption in someone's head. The Solutions Architect can overrule
any of them and the affected RTVM item will be reissued.

| # | Question scope left open | Decision taken | Affects |
| --- | --- | --- | --- |
| I-1 | Line endings | LF and CRLF both accepted; trailing newline optional. Windows-targeted software that rejected CRLF would be indefensible. | RTVM-106 |
| I-2 | Content after line 9 | Ignored. Fewer than 9 lines is malformed. Lets a script pipe a puzzle followed by anything without a spurious rejection. | RTVM-102, RTVM-106 |
| I-3 | Whitespace | Leading/trailing horizontal whitespace on a line is stripped before the 9-character check; interior whitespace is an illegal character. | RTVM-106 |
| I-4 | Stream for the "no solution" statement | **stdout.** §4.1 step 5 lists it as the printed *result*; §4.3's parenthetical listing of stdout content omits it. §4.1 is the more explicit of the two and is followed. A scripted caller branches on exit `2` regardless. | RTVM-402, RTVM-406 |
| I-5 | Stream for the abort message | **stderr**, as a §4.4 prompt-flow message. stdout stays byte-empty on an aborted run. | RTVM-404 |
| I-6 | Timing tolerance | ±1.0 s on the 15 s and 10 s prompt thresholds. A hard equality is untestable on a general-purpose OS. | RTVM-501, RTVM-502 |
| I-7 | One fault or all faults | One — the first found, in the precedence order shape → character → contradiction. Deterministic messages, deterministic tests, and it matches "says specifically what is wrong" better than a list does. | RTVM-105 |
| I-8 | Bound on non-uniqueness detection | The search stops at two solutions. §4.5 puts counting all solutions in a later tier, so finding two is sufficient and finding more is out of scope. | RTVM-202 |
| I-9 | Missing or unreadable file argument | Treated as invalid input: specific stderr diagnostic, exit `1`. Not covered by §4.1, but it is the only exit code whose meaning fits. | RTVM-009 |
| I-10 | How a >15 s solve is produced for test | A build-provided diagnostic hook (RTVM-507). A "pathological" puzzle cannot be relied on: any solver good enough to meet the 10 s budget on `P-HARD17` will also dispatch the known brute-force-hostile grids in milliseconds, so there is no input that reliably exercises the prompt path. | RTVM-507 |
| I-11 | Abort latency | 1.0 s from response to solver return. Unspecified in scope; without a number "the user can stop it" is not verifiable. | RTVM-203 |
| I-12 | "Never silent" vs. the deliberate 15 s of silence before the first prompt | Two bounds, not one: **16.0 s** from process start to the first output, **11.0 s** between outputs thereafter. Found while writing the SDD — as originally worded, RTVM-504 imposed a single 11.0 s bound measured from process start, which RTVM-501 (first prompt at 15 s) contradicts outright, making TP-504 unpassable by any conforming implementation. Resolved in favour of RTVM-501, because `docs/PROJECT_DEFINITION.md` §4.4 states the 5 s gap between the 10 s budget and the 15 s prompt is *deliberate* — a puzzle that only just overruns must finish without nagging. The alternative fix, a start-up banner on stderr, was rejected for defeating that stated intent. **No scope change: the program's behaviour is unaltered, only the bound RTVM-504 asserts.** | RTVM-504, RTVM-006 |
| I-13 | Upper bound on bytes read while looking for a 9-character line | A single line is capped at 4096 bytes before being declared malformed. Within the cap, the exact observed length is reported (TP-102 expects that); beyond it, "more than 4096 characters". Needed so TP-505's 1 MB single line and 10 000-line cases produce the same shape fault promptly rather than buffering a megabyte to reach the same answer. Does not change which inputs are accepted — every input over 9 characters is malformed either way. | RTVM-102, RTVM-505 |
| I-14 | What "Windows 10/11" in §6.3 means for the machine timings are actually taken on | The GitHub-hosted `windows-latest` image (Windows Server 2022, x64, 4 vCPU, 16 GB) **is** an acceptable §6.3 reference machine and is the normative one for TP-500…504. It shares the kernel, the MSVC toolset and the ABI of Windows 11; §6.3's intent was to exclude an underpowered or loaded machine, not to distinguish client from server SKUs. TP-500's existing requirement to report the machine it ran on is what keeps this honest. Raised because §9.1.3 wires the timing set onto exactly that runner, and "we measured on the wrong machine" is a cheap objection to close now and an expensive one to close at acceptance. | RTVM-500…504, §6.3, §9.1.3 |

## 8. Carried forward to the SDD — **CLOSED 2026-08-07 (issue #3)**

Not RTVM line items — recorded here so they were not lost between
issues. All five are now answered in `docs/SDD.md`; the pointers below
are kept so the trail from requirement to decision stays readable.

1. **§4.4.1 architecture discovery.** ✅ Answered in `docs/SDD.md` §1.2
   and §1.3. **No multi-threading.** The application is single-threaded:
   the prompt timer and the stop-response check are *polled* from inside
   the solver's search loop via a `SolveControl` callback, so nothing
   ever waits and there is nothing to run concurrently. The non-blocking
   read of standard input dispatches on `GetFileType` — console
   (`PeekConsoleInput` for a pending `VK_RETURN`), pipe
   (`PeekNamedPipe`), file (`ReadFile`, EOF latches), or null. `§1.2`
   carries a constraint-by-constraint table against §4.4.1's six.
2. **Algorithm choice.** ✅ `docs/SDD.md` §1.5 — bitmask constraint
   propagation (naked and hidden singles) to fixpoint, then depth-first
   search ordered by minimum remaining values, candidates tried in
   ascending digit order, `maxSolutions = 2`. Rejected alternatives
   recorded there.
3. **Test framework choice.** ✅ `docs/SDD.md` §3.3 —
   `Microsoft::VisualStudio::CppUnitTestFramework` (VS 2022 native unit
   test project). Chosen because it ships with the C++ workload and so
   is not a third-party dependency (RTVM-902); GoogleTest, Catch2 and
   doctest rejected as requiring vendoring.
4. **`DELIV` items RTVM-900…907.** ✅ `docs/SDD.md` §3.1–§3.4 is the
   build and toolchain conventions section those inspections read.
   RTVM-903 is carried by §1.1 (a static-library split that makes the
   separation structural) and §2.3 (`kGridSize` derived from
   `kBoxSize`, with a `static_assert` guarding the later 16×16 tier).
5. **Data architecture.** ✅ **Not required** — the §4.4.1 answer
   introduces no second thread and no second process, so the SDD's Data
   Architecture section is deliberately absent. `docs/SDD.md` §1.4
   records that as a decision, and states what would have to be
   specified if a future tier ever moves the solver off the main thread.

Two RTVM defects were found while writing the SDD and are fixed above:
§7 **I-12** (RTVM-504 contradicted RTVM-501, making TP-504 unpassable)
and §7 **I-13** (an unbounded line read behind TP-505). Neither changes
scope or program behaviour.

## 9. Verification environment, and partial verification of the DELIV set

### 9.1 The constraint, the policy, and how Windows verification is wired

#### 9.1.1 The constraint

Every agent run in this pipeline executes on an **Ubuntu runner with
no Visual Studio, no MSVC toolset and no `msbuild`**. Everything in
this RTVM is specified against Windows and VS 2022, so an inspection
or test procedure divides into clauses that can be executed here
(file contents, project settings read as XML, source-level greps,
behaviour of a `g++ -std=c++17` build of the same sources) and clauses
that cannot (the solution opening in VS 2022, an MSVC `Debug|x64` /
`Release|x64` build, Test Explorer / `vstest.console.exe` discovery,
console-handle behaviour, a clean-machine run).

**This does not weaken any requirement or any procedure.** No test
procedure is rewritten to fit the runner, and nothing is marked
Verified on the strength of a substitute toolchain. The constraint is
recorded here so that:

- a partially-executed procedure is never recorded as if it were
  fully executed (§9.2 is the ledger of what was actually run), and
- the remaining Windows-only clauses are visible now rather than
  discovered at TP-500.

#### 9.1.2 The policy (issue #23, Solutions Architect)

Settled in `docs/PROJECT_DEFINITION.md` **§7.1**, rules **V-1…V-7**,
which is authoritative; summarised here only so this section reads
without a second document open. No scope change: Windows / x64 /
C++17 / VS 2022 stands.

- **V-1** substitute-toolchain results are *evidence, never a verdict*.
- **V-2** the Windows-only clauses must actually run on Windows before
  the MVP is complete; a blanket "accept the gap" is rejected.
- **V-3** primary route is Windows verification **inside this
  pipeline** (`windows-latest`). §6.3 already names that runner as the
  reference machine, so nothing in this RTVM is reissued.
- **V-4/V-5** a client-acceptance pass is a narrow fallback only, one
  itemised justified clause at a time, agreed **in advance** — §9.4.
- **V-6** partial execution is recorded as partial — §9.2 is the shape.
- **V-7** the Ubuntu build may be used as an aid but must never become
  a delivered target and must never constrain the source.

#### 9.1.3 Wiring decision — W-1…W-8

*How* Windows verification is wired is a build-tooling decision, taken
here per §7.1's assignment of it to the Systems Engineer.

| ID | Decision | Reason |
| --- | --- | --- |
| **W-1** | Windows verification is a **separate workflow**, `.github/workflows/windows-verification.yml`, `runs-on: windows-latest`. It is *not* a Windows leg of `agent-relay.yml`. | The agents don't need Windows; the *build and the executable* do. Moving the relay to Windows would change the toolchain under all five roles and slow every run, to fix one role's problem. |
| **W-2** | It **executes and publishes evidence; it never issues a verdict** and never sets a `status:*` or `agent:*` label. The Test Engineer reads its output and rules. | V-1 draws the line between evidence and verdict, and that line has to exist in the tooling, not just in prose. A green Windows job is an input to TP-9xx, not a pass. |
| **W-3** | Trigger: `push` on `issue-*` and `main`, plus `workflow_dispatch` for humans. **No trigger requires an agent to call the Actions API.** | The agent token has `actions: read` only (§9.1.4). A push-triggered design means the Windows evidence already exists, attached to the exact SHA, by the time the Test Engineer looks — no dispatch, no polling, no extra permission. |
| **W-4** | Jobs, in order, each step named for the procedure it feeds: `msbuild` restore + `Debug\|x64` + `Release\|x64` (TP-900/901/906); `vstest.console.exe` against the test DLL (TP-905); a runtime matrix of the CLI/output/exit-code procedures against the Release build (TP-001…009, TP-4xx, TP-505); the timing set on Release only (TP-500…504 via the RTVM-507 hook); `dumpbin /dependents` on the delivered exe (TP-506, automatable clause). | One job per phase would multiply checkout and build cost for no isolation benefit; one *step* per procedure keeps the log greppable by TP id, which is what the Test Engineer actually reads. |
| **W-5** | Evidence is published three ways: a `$GITHUB_STEP_SUMMARY` table keyed by **TP id** with `PASS` / `FAIL` / `NOT-RUN`; an artifact `windows-evidence-<sha>` containing build logs, the `.trx`, raw stdout/stderr captures and timing samples, retention 90 days; and the machine's specs printed into the summary. | The Test Engineer runs on Ubuntu and reaches all of this read-only through `gh run list --branch issue-<n>`, `gh run view --log` and the artifacts API — all within `actions: read`. The machine line is not decoration: TP-500 requires the run to report the machine it ran on. |
| **W-6** | The workflow **fails the job on a build or test failure** rather than swallowing it, but a failed job is still evidence, not a defect report. | A red job that no one is obliged to interpret is how a Windows gap becomes decorative. The Test Engineer raises the defect; the workflow just refuses to look green while broken. |
| **W-7** | The timing set is run on the Release build only, three times, with all samples reported. A tolerance breach is reported with all three samples rather than retried until green. | `windows-latest` is shared-tenant and jittery; §7 I-6's ±1.0 s is the tolerance, and hiding variance behind a retry-until-pass would make TP-501/502 meaningless. Three samples make jitter visible as jitter. |
| **W-8** | The workflow must not add, and must not require, any cross-platform build file, and must build the committed `.sln` **exactly as the client would** — no injected properties, no `/p:` overrides beyond `Configuration` and `Platform`. | V-7, `D-7`, RTVM-901/906. A build that only succeeds with CI-only switches has verified a project the client doesn't have. |

The full workflow is written and committed at
**`docs/ci/windows-verification.yml`**, ready to copy to
`.github/workflows/`. It is parked outside `.github/workflows/` for the
reason in §9.1.4, not by preference.

#### 9.1.4 What no agent in this pipeline can do — measured, not assumed

Both of the following were probed on this runner on 2026-08-07 with the
live relay token, not inferred:

1. **No agent can create or update a workflow file.** Pushing a branch
   containing `.github/workflows/probe-delete-me.yml` is rejected by the
   remote: `refusing to allow a GitHub App to create or update workflow
   '.github/workflows/probe-delete-me.yml' without 'workflows'
   permission`. The probe branch was deleted; nothing remains.
2. **No agent can dispatch a workflow either.** `gh workflow run
   dependency-check.yml` returns `HTTP 403: Resource not accessible by
   integration`. The installation has `actions: read` — listing
   workflows and runs works — but not `actions: write`.

So V-3 cannot be completed by any agent. It needs **exactly one action
from the repository owner**, either of:

- **(a)** grant the relay GitHub App installation **Workflows:
  read & write**, after which CI/CD adds and maintains
  `.github/workflows/windows-verification.yml` itself and the pipeline
  stays self-maintaining; **or**
- **(b)** copy `docs/ci/windows-verification.yml` to
  `.github/workflows/windows-verification.yml` and commit it once. No
  permission change; the cost is that every later edit to that file
  needs a human again.

`actions: write` is **not** required by the W-3 design and is not part
of the ask — it would only be needed for on-demand dispatch, which the
push trigger makes unnecessary. Keeping the ask to one permission is
deliberate.

Until either lands, every Windows-only clause in §9.2 and §9.4 stays
outstanding and the affected requirements stay below Verified. This is
recorded rather than absorbed: per §7.1's closing paragraph it went
straight back to the Solutions Architect on issue #23.

### 9.2 DELIV coverage after the Generate Code Base scaffold

State at branch `issue-5` @ `04b0269`, inspected by the Test Engineer
2026-08-07. "Executed" means the procedure's clause was actually run
against the tree, not read. **This table is the standing shape for any
partially-executed procedure** (V-6), not a one-off: a procedure with
unexecuted clauses gets a row here naming them.

| Req | Executed here and passed | Still outstanding |
| --- | --- | --- |
| RTVM-900 | `.sln` + three `.vcxproj` tracked in git; all six project files parse as XML; every `ClCompile`/`ClInclude` path exists; solution GUIDs match project GUIDs; `WindowsTargetPlatformVersion` = `10.0` in all three | TP-900's second sentence — the solution opening in VS 2022 with no "project unavailable" and no migration prompt |
| RTVM-901 | — | All of TP-901: clone, open, Build, on a machine that has never built this. Needs the README (RTVM-904) first |
| RTVM-902 | **All of TP-902.** No `packages.config` / `vcpkg.json` / `conanfile` / NuGet reference / vendored tree; the only paths outside the repo are `$(VCInstallDir)Auxiliary\VS\UnitTest\{include,lib}` (MSVC toolset) | — |
| RTVM-903 | **All of TP-903.** Zero console/stream/`argv` references under `src/SudokuCore/`; single bare `9` is `kGridSize`'s own definition; the core links into a test driver with no console-layer object file present | Re-confirm the link clause under MSVC rather than `g++`. Evidence, not verdict, is what changes |
| RTVM-904 | Seven §3.4 headings present as stubs | All TP-904 content clauses — issue #22 |
| RTVM-905 | Test project present in the solution; both placeholder methods compile and pass under a `CppUnitTest.h` shim | TP-905's real clause — discovery and execution through Test Explorer / `vstest.console.exe`, plus the README command |
| RTVM-906 | **All of TP-906.** `stdcpp17` in both configurations of all three projects; `Debug\|x64` and `Release\|x64` are the only configurations anywhere; no `CMakeLists.txt` / `Makefile` / `meson.build` / other cross-platform build file | — |
| RTVM-907 | Fixture clause: all five `samples/*.txt` identical to their §6.1 fixtures, 90 bytes each, LF, no trailing blank line | The README clause — all five named with their expected outcome (rides with RTVM-904) |
| RTVM-506 | `/MT` `/MTd` set on `SudokuSolver` and `SudokuCore`; the test DLL's `/MD` does not touch the delivered exe (§9.3) | All of TP-506 — the clean-machine run |

Requirements whose procedure is fully executed above are **In Test**;
the rest are **In Implementation** until their own issue delivers the
missing part. Nothing here is Verified: Verified is set when CI/CD
reports the commit and the DELIV inspection issues (#21, #22, #14)
close.

### 9.3 Scaffold decisions recorded against requirements

Two decisions taken at Generate Code Base that a later reader would
otherwise have to reverse-engineer from the project files:

1. **The test DLL alone links the dynamic CRT** (`/MD`, `/MDd`),
   because `CppUnitTestFramework` ships linked against it. This is the
   fallback `docs/SDD.md` §3.7 pre-authorised and it leaves RTVM-506
   untouched — RTVM-506 constrains the delivered executable, and the
   delivered executable is still `/MT`. Consequence: the test project
   compiles `SudokuCore`'s `.cpp` files as its own sources rather than
   linking the `/MT` library. The `ProjectReference` is kept
   (`LinkLibraryDependencies=false`) so RTVM-903's dependency
   direction stays structural. Recorded in `docs/SDD.md` §3.7.
2. **`.gitignore` and `.gitattributes` were requirements in
   disguise.** The template `.gitignore` excluded `*.sln`, which would
   have made RTVM-900 fail silently — a repository of source files
   with no committed solution. `.gitattributes`' `* text=auto` would
   have checked `samples/*.txt` out as CRLF on Windows and broken
   TP-907's byte-for-byte diff. Both are now pinned; `docs/SDD.md`
   §3.1 states the convention so a future edit doesn't undo it.

### 9.4 V-4 candidates — clauses a `windows-latest` runner still cannot execute

**Status: draft, not agreed.** V-4 permits a client-acceptance pass
only for clauses a hosted Windows runner *genuinely* cannot execute,
and V-5 requires the list to be agreed in advance. This is my
first-pass candidate list; each row states the automation route I
believe closes it, because the honest version of this list is short.
It is confirmed with the Test Engineer against a real Windows job —
several rows are expected to *leave* the list at that point, and no
row leaves this table for the client until it has survived that.

| # | Clause | Why a hosted runner may not reach it | Proposed automation route before conceding it | Recommendation |
| --- | --- | --- | --- | --- |
| A-1 | **TP-506** — run the exe on a clean Windows machine with no VS, no redistributable, no build tools | Every hosted Windows image ships the full VS toolchain and the VC++ runtimes, so "runs where the runtime was never installed" cannot be demonstrated there — the negative is unobservable on the only machine we have | `dumpbin /dependents` asserting the import list is stock system DLLs only (`KERNEL32`, `USER32`, …) with no `MSVCP140.dll` / `VCRUNTIME140*.dll` — TP-506's own last sentence, and it is strong evidence | **Genuine V-4 item.** Automate the `dumpbin` clause; the launch-on-a-clean-machine clause goes to client acceptance |
| A-2 | **TP-900** — the solution *opening* in VS 2022 with no "project unavailable" and no migration prompt | The prompt is modal GUI behaviour; a headless runner never renders it | `devenv.exe SudokuSolver.sln /Build "Debug\|x64"` uses the same solution loader as the IDE and fails or hangs where the IDE would prompt; combined with a toolset/`ToolsVersion` inspection this covers the substance | **Probably not a V-4 item.** Try `devenv /Build` first; concede only if it proves not to reproduce the loader path |
| A-3 | **TP-905** — tests appearing in **Test Explorer** | Test Explorer is a GUI surface | `vstest.console.exe` is the discovery and execution engine Test Explorer drives; if it discovers and runs both methods, the substantive claim holds | **Not a V-4 item** on current evidence. Expect to close by automation |
| A-4 | **TP-004…008** — the console-handle behaviour (`PeekConsoleInput`, `GetFileType` = console, an interactive-equivalent stdin held open) | A runner step has no interactive console attached: stdin is a pipe or `NUL`, so `GetFileType` never reports a console and the console path is never entered. TP-008's redirected half runs fine; TP-004/005/006's do not | Drive the exe under a **ConPTY pseudoconsole** (`CreatePseudoConsole`, available on Windows Server 2022) from a small harness, so the child genuinely sees a console handle. This is the same mechanism Windows Terminal uses and it is not exotic | **Undecided — needs a feasibility spike on #17** before it goes anywhere near the client. If ConPTY works this whole row disappears, and it is the largest row on the list |
| A-5 | **TP-500…504** — the timing set | Shared-tenant runner jitter against a ±1.0 s tolerance (§7 I-6) | W-7: three samples, Release build, all reported | **Not a V-4 item.** Run it; if the tolerance proves unholdable *with data in hand*, that is a requirements question for me, not a client-acceptance one |
| A-6 | **TP-901** — build "on a machine that has never built this project" | — none; a fresh hosted runner satisfies this clause **better** than a client engineer's machine, which has VS configured and a warm state | n/a | **Not a V-4 item.** Recorded only to stop it being added later by association |

Nothing on this list is surfaced to the client until it is down to the
rows that survive A-2, A-3 and A-4's automation attempts — per V-5 that
is the Solutions Architect's step, and a two-row list is a decision
where a six-row one is a shrug.

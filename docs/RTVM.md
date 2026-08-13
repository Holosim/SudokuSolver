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
| RTVM-100 | The application parses 9 lines of 9 characters into an internal 9×9 grid in which each cell holds either a given digit 1–9 or "empty". | SN-1, SN-2 | Test (TP-100) | In Test | `3bc1b22` |
| RTVM-101 | Both `0` and `.` denote an empty cell, interchangeably, including mixed within the same puzzle. | SN-1 | Test (TP-101) | In Test | `3bc1b22` |
| RTVM-102 | Input whose shape is wrong — fewer than 9 lines, or any of the first 9 lines not exactly 9 characters after the rules of RTVM-106 are applied — is rejected as malformed with a message naming the offending line number and what was wrong with it. Interior horizontal whitespace is the one exception to that length test: it is reported as an illegal character (RTVM-103), not as a length fault on its own line — §7 I-15. | SN-4 | Test (TP-102) | Approved | |
| RTVM-103 | Input containing a character other than `1`–`9`, `0` or `.` in the grid is rejected as malformed with a message naming the offending character and its row and column. | SN-4 | Test (TP-103) | Approved | |
| RTVM-104 | Input that is well-formed but self-contradictory — the same digit given twice in a row, a column, or a 3×3 box — is rejected with a message naming the digit, the unit, and both conflicting cells. | SN-4 | Test (TP-104) | Approved | |
| RTVM-105 | Validation reports exactly one fault, the first found, in the fixed precedence order: shape (RTVM-102) → illegal character (RTVM-103) → contradiction (RTVM-104). The single exception is interior horizontal whitespace, which outranks the length fault of the line it appears on and is reported as an illegal character (§7 I-15); precedence between different lines is unaffected. Cells are named in one-based `r<row>c<col>` form. A rejected puzzle is never passed to the solver. | SN-4 | Test (TP-105) | Approved | |
| RTVM-106 | Input is accepted with either LF or CRLF line endings and with or without a trailing newline. Leading and trailing horizontal whitespace on a line is ignored; interior whitespace is an illegal character. Content after the ninth line is ignored. | SN-1, SN-8 | Test (TP-106) | In Test | `3bc1b22` |
| **CORE — solver (§4.4, §4.5, §5)** | | | | | |
| RTVM-200 | Given a valid, uniquely-solvable standard 9×9 puzzle, the solver produces the grid's unique solution: all 81 cells filled with 1–9, with no digit repeated in any row, column, or 3×3 box, and every given preserved in place. | SN-2 | Test (TP-200) | In Test | `fdd9cea` |
| RTVM-201 | Given a well-formed, non-contradictory puzzle that admits no completion, the solver reports "no solution" and terminates. It does not loop, guess indefinitely, or emit a partial grid. | SN-2, SN-4 | Test (TP-201) | Approved | |
| RTVM-202 | The solver determines whether a puzzle has more than one solution by searching for at most two solutions and stopping. Where two are found it yields the first found together with a "not unique" indication. It does not enumerate or count all solutions. | SN-2, SN-3 | Test (TP-202) | Approved | |
| RTVM-203 | The solve is cooperatively interruptible: once an abort is requested the solver stops and yields the "aborted" outcome within 1.0 s, leaving the process free to exit cleanly. | SN-5 | Test (TP-203) | Approved | |
| RTVM-204 | The solver maintains a monotonically increasing count of search steps taken, readable by the rest of the application and by the test suite while the solve is in flight. This is what makes "the solve is still making progress" (§7 acceptance #6) an observable fact rather than an assertion. | SN-5 | Test (TP-204) | Approved | |
| **DATA-OUT — internal representation of output (§4.1, §4.3)** | | | | | |
| RTVM-300 | Every run produces exactly one outcome drawn from the closed set: `Solved`, `SolvedNotUnique`, `InvalidInput`, `NoSolution`, `Aborted`. There is no run that produces none and no run that produces two. | SN-3, SN-4, SN-8 | Test (TP-300) | In Test | `668f9a4` |
| RTVM-301 | The `Solved` and `SolvedNotUnique` outcomes carry a complete 9×9 grid of digits 1–9 with no empty cell. | SN-3 | Test (TP-301) | In Test | `668f9a4` |
| RTVM-302 | The `InvalidInput` outcome carries structured fault detail (fault kind, line/row/column, digit or character involved) rather than a pre-formatted message, so that all wording lives in the output layer. | SN-4, SN-7 | Test (TP-302) | In Test | `668f9a4` |
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
| RTVM-506 | The delivered executable is a self-contained x64 Windows console application that runs on a clean Windows machine with no installed runtime or third-party component beyond what a stock Windows install provides. | SN-6, SN-7 | Test (TP-506) | In Implementation | `85bab27` |
| RTVM-507 | The build provides a documented diagnostic means of forcing a solve to run past the prompt thresholds without altering ordinary behaviour, so that RTVM-004…008 and RTVM-501…504 are verifiable end-to-end. It is documented in `docs/SDD.md`, not in the user-facing README, and is inert in normal use. | SN-5 | Test (TP-507) | Approved | |
| **DELIV — deliverable requirements (§6). Verified by inspection.** | | | | | |
| RTVM-900 | The repository contains a committed, openable Visual Studio 2022 solution and project file(s) — not source files alone. (D-1) | SN-7 | Inspection (TP-900) | In Test | `85bab27` |
| RTVM-901 | A client engineer can clone, open, build, and run the solution in VS 2022 with no setup step that is not written down in the README. (D-2) | SN-7 | Inspection (TP-901) | In Implementation | `85bab27` |
| RTVM-902 | The solution builds with the stock VS 2022 toolchain and the C++ standard library alone. No third-party library, package manager, or downloaded dependency of any kind. (D-3) | SN-7 | Inspection (TP-902) | Verified | `85bab27` |
| RTVM-903 | The solver core is a separate compilation unit / module from the console I/O layer and has no dependency on stdin, stdout, stderr, or command-line parsing. The grid dimension appears as a single named constant, not as literal `9`s scattered through the code. (D-4) | SN-7 | Inspection (TP-903) | In Test | `85bab27` |
| RTVM-904 | The repository carries a README covering how to build, how to run, and the puzzle input format. (D-5) | SN-7 | Inspection (TP-904) | In Implementation | `85bab27` |
| RTVM-905 | Automated tests are part of the delivered solution and are runnable by the client through a documented command or VS action. (D-6) | SN-7 | Inspection (TP-905) | In Implementation | `85bab27` |
| RTVM-906 | The solution targets C++17 and x64, and is a Visual Studio solution only — the repository contains no CMake or other cross-platform build files. (D-7) | SN-7 | Inspection (TP-906) | Verified | `85bab27` |
| RTVM-907 | Five sample puzzles ship with the solution and are referenced from the README: easy, hard 17-clue, unsolvable, malformed, and non-unique. (§4.2) | SN-1, SN-7 | Inspection (TP-907) | In Test | `85bab27` |

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

Both of these behave identically whichever way §7 I-15 is read, so they
do not exercise it. The case that does is TP-106's negative fixture
(`098 000060`), which is the normative test of the whitespace exception;
TP-105 only has to leave it undisturbed. Add one confirmation that the
exception really is narrow: `P-EASY` with line 5 as `40080300111`
(11 characters, no whitespace, `P-LONGLINE`) still reports
`LineTooLong` on line 5, and `P-MULTIFAULT` — 8 lines *and* an `X` —
still reports the missing line.

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

That fixture is 10 characters, so the fault it must report is fixed by
**§7 I-15** and not by RTVM-105's plain ordering: the interior space is
classified as an illegal character during the shape pass and outranks
line 3's own length. At unit level the assertion is `!ok()`,
`kind == FaultKind::IllegalCharacter`, `character == ' '`,
`first == {3,4}`, `line == 3` — *not* `LineTooLong`. Column 4 is
counted in the line as it stands after leading and trailing whitespace
is stripped. Ruled 2026-08-13 on issue #6, where the Software Engineer
and Test Engineer both raised the conflict.

### CORE

**TP-200 — correct solve.** Solve `P-EASY`, `P-HARD17` and `P-SEARCH`.
Expect exactly `S-EASY`, `S-HARD17` and `S-EASY` respectively (§6.1).
For each result, assert programmatically: 81 cells all in 1–9; every
row, column, and 3×3 box is a permutation of 1–9; every given in the
input appears unchanged at the same position.

`P-SEARCH` is the **branch-and-backtrack case**, added 2026-08-13 after
the issue #8 test pass showed both original fixtures fall to constraint
propagation alone (`nodesExplored == 1`), leaving the search half of
`docs/SDD.md` §1.5 un-exercised by this procedure — see §9.7. For
`P-SEARCH` additionally assert `nodesExplored() > 1`, i.e. that at
least one branch was taken. Assert the **inequality, not a count**: the
node total is an implementation property, not a requirement, and
pinning it would fail on any legitimate propagation improvement. (For
reference only, measured against the delivered solver at `c662bb1`:
`P-SEARCH` 5 nodes, `P-EASY` 1, `P-HARD17` 1.)

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

`P-SEARCH` — valid, uniquely solvable, 25 givens. Dug from `S-EASY`, so
**its unique solution is `S-EASY`** and no new solution fixture is
needed. Its purpose is coverage, not difficulty: unlike `P-EASY` and
`P-HARD17` it is **not** solvable by naked and hidden singles alone, so
it is the fixture that forces the §1.5 MRV branch/backtrack path to run
(§9.7):

```
504000910
002000040
090000000
050700400
000003000
700020806
960037000
080400600
000200170
```

Machine-verified 2026-08-13, three independent properties: exactly one
solution (exhaustive search stopped at a second, none found); that
solution is byte-identical to `S-EASY`; and naked + hidden singles run
to fixpoint leave the grid incomplete with no contradiction, i.e. a
guess is unavoidable. Every given agrees with `S-EASY` at the same
position by construction.

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
| I-14 | What "Windows 10/11" in §6.3 means for the machine timings are actually taken on | **Amended 2026-08-13 — the parenthetical below was factually wrong and the label, not the image, is what is normative.** The reference machine is *whatever image the `windows-latest` label resolves to on the day of the run*, and the run's own machine block is the record of it (W-9). On 2026-08-13 that was **`win25-vs2026`: Windows Server 2025 10.0.26100, AMD EPYC 9V74, 2 cores / 4 logical, 16 GB** — not the Windows Server 2022 image this interpretation originally named. The ruling below is unchanged and the reasoning survives intact; only the machine identity was wrong, and it was wrong because it was assumed rather than read. Original text follows. ~~The GitHub-hosted `windows-latest` image (Windows Server 2022, x64, 4 vCPU, 16 GB)~~ The GitHub-hosted `windows-latest` image **is** an acceptable §6.3 reference machine and is the normative one for TP-500…504. It shares the kernel, the MSVC toolset and the ABI of Windows 11; §6.3's intent was to exclude an underpowered or loaded machine, not to distinguish client from server SKUs. TP-500's existing requirement to report the machine it ran on is what keeps this honest. Raised because §9.1.3 wires the timing set onto exactly that runner, and "we measured on the wrong machine" is a cheap objection to close now and an expensive one to close at acceptance. | RTVM-500…504, §6.3, §9.1.3 |
| I-15 | Which fault a line carrying **interior whitespace** reports, when that whitespace also makes the line the wrong length | **The illegal character**, at its `r<row>c<col>` position, in preference to a length fault on that same line. The exception is exactly that narrow: it applies only to horizontal whitespace, and only against the length check of the line the whitespace is on. RTVM-105's order is otherwise untouched — fewer than 9 lines still outranks any character fault anywhere, and a non-whitespace illegal character still loses to a length fault on its own line. Reasons: (a) RTVM-106 declares interior whitespace an illegal character, and under strict shape-first precedence that clause is nearly unreachable, since a line carrying an extra space is by construction not 9 characters; (b) TP-106's negative fixture `098 000060` is 10 characters and asserts the illegal-character message, so the two documents contradicted each other as written; (c) "illegal character ' ' at r3c4" locates the fault, "line 3 has 10 characters" does not, and RTVM-102/103 exist to say *what* is wrong. Column position is counted after leading/trailing whitespace is stripped. Raised on issue #6 by the Software Engineer (implemented this reading) and the Test Engineer (tested it, declined to rule); ruled 2026-08-13. No scope change and no behaviour change against the delivered parser — this records the reading it was built and passed under. | RTVM-102, RTVM-103, RTVM-105, RTVM-106 |
| I-16 | **Where** the 0-based → 1-based cell conversion happens, given that `docs/SDD.md` §2.3 said "in exactly one place, in `Messages`" while §2.5 declared `CellRef` already **1-based** | **At fault construction, not at rendering.** An `InputFault` carries 1-based cells; `Messages` renders `r<row>c<col>` straight from the fault and performs no arithmetic. The two SDD clauses could not both hold — if the fault already carries 1-based cells, the `+1` must have happened before `Messages` ever sees it. Resolved in favour of §2.5 because (a) the parser delivered at [RTVM-100] (#6) already stores 1-based cells and passed TP-100/TP-106 that way, (b) TP-302 as written inspects the *fault object* for `r1c1`/`r1c7` with no output layer in the picture, so the fault is where the 1-based form has to exist, and (c) `Messages` is the one place English lives (§2.5, §2.7) — giving it arithmetic as well makes it two responsibilities. §2.3's "exactly one place" intent is preserved literally: the `+1` is spelled once, in `cellRefFromZeroBased()` in `InputFault.h`, and every fault-producing path calls it rather than adding one itself. An out-of-grid coordinate yields a *not applicable* `CellRef` rather than a wrapped one (RTVM-505). `docs/SDD.md` §2.3 and §2.5 both reworded to say this. Raised on issue #7 by the Software Engineer and seconded by the Test Engineer; ruled 2026-08-13. No scope change and no behaviour change against the delivered code — this records the reading it was built and passed under. | RTVM-103, RTVM-104, RTVM-105, RTVM-302 |
| I-17 | What "VS 2022" in `D-1`/`D-3` constrains: the **artifact**, or the **machine that builds it** | **The artifact.** RTVM-900/901/906 are satisfied by a solution and project files that Visual Studio 2022 opens and builds with the `v143` toolset and ISO C++17 — the *delivered thing* is what carries the constraint. It does not follow that every build taken as evidence must be performed by a VS 2022 installation. Consequences, and they cut both ways: (a) the `Debug\|x64` / `Release\|x64` builds on the `win25-vs2026` runner **are** valid evidence for RTVM-901's "builds clean" and RTVM-906's language-standard clause, because the compiler actually invoked is `PlatformToolset=v143` / MSVC 14.44 — the VS 2022 toolset, shipped side-by-side in the newer install; (b) they are **not** evidence for TP-900's *"opens in VS 2022 with no migration prompt"*, which is a claim about the VS 2022 solution loader and can only be discharged by a VS 2022 loader — a newer IDE opening the solution demonstrates forward compatibility, and the requirement runs the other way. The committed artifacts remain pinned to VS 2022 form (`.sln` `Format Version 12.00` / `# Visual Studio Version 17` / `VisualStudioVersion = 17.0.31903.59`; `PlatformToolset=v143`; `WindowsTargetPlatformVersion=10.0`), and **no project file may be retargeted to satisfy a runner** — that is V-7 applied to MSVC exactly as it already applies to `g++`. Raised by the Systems Engineer on issue #23 after reading the first Windows run (§9.1.5); it is scope-adjacent, so it is **flagged to the Solutions Architect for confirmation** as I-14 was. No scope change and no change to any delivered file. | RTVM-900, RTVM-901, RTVM-906, §9.4 A-2 |

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

**Installed 2026-08-13 via route (b)** (§9.1.4): the repository owner
copied `docs/ci/windows-verification.yml` to
`.github/workflows/windows-verification.yml` and committed it as
**`fc23901`**. The two files were byte-identical at that commit. W-1…W-8
are in force as written; the first two runs are assessed in §9.1.5.

Three further decisions taken 2026-08-13, after reading what the first
runs actually produced. W-9 and W-11 are consequences of V-10 (a
workflow file can only be changed by the repository owner); W-10 is the
lesson from a defect that would otherwise have cost a round trip to fix.

| ID | Decision | Reason |
| --- | --- | --- |
| **W-9** | **`windows-latest` is a moving image, and no machine fact about it may be quoted from a previous run.** Every run prints its own machine block; any timing figure, toolset version or "the runner has X installed" claim is read from the machine block of *the same run*. §6.3 / §7 I-14 name the *label*, never a specific image. | Measured, not theoretical: the image on 2026-08-13 was `win25-vs2026` — Windows Server 2025 and Visual Studio 2026 — where I-14 as originally written said Windows Server 2022 and everyone in this thread, me included, had been assuming VS 2022 was present (§9.1.5, and I-14 as amended). An image assumption that is right today is a silently wrong acceptance record in three months. |
| **W-10** | **Anything that can live in `tests/windows/*.ps1` lives there and not in the workflow.** The workflow's job is: build, locate outputs, invoke the script hooks, summarise, publish. Procedure logic, probes and one-off spikes go in the agent-writable scripts. | V-10 makes every line inside `.github/workflows/` a repository-owner commit; every line inside `tests/windows/` is a normal agent push. The TP-905 defect in §9.1.5 is fixable *today* from `run-procedures.ps1` and would otherwise have waited on a human. Design for the permission boundary rather than around it. |
| **W-11** | **`docs/ci/windows-verification.yml` is the maintained source; `.github/workflows/windows-verification.yml` is the installed copy.** A `diff` between the two *is* the pending-install queue. Pending edits are **batched into one owner commit**, never trickled, and the head of `docs/ci/…` carries a dated `PENDING — NOT YET INSTALLED` block listing them. | Each install is a human interruption. Asking three times for three one-line fixes spends the client's goodwill on our own sequencing, and a silent divergence between the two files is worse than either. |

#### 9.1.4 What no agent in this pipeline can do — **RESOLVED 2026-08-13 via route (b); the constraint itself is permanent (V-10)**

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

##### Outcome, 2026-08-13 — and a correction to the two-option framing

The repository owner took **route (b)**: the file was copied to
`.github/workflows/windows-verification.yml` and committed as
`fc23901`, and the workflow ran on that push (run `31723230235`, green,
artifact published). V-3 is live.

**Route (a) was never actually available**, and that is the more
important half of the answer. The GitHub App this pipeline runs under
requests only *Contents*, *Pull Requests* and *Issues* — it does not
declare a `workflows` permission at all, and an installer cannot grant
a permission an app has not declared. So (b) was not the
lower-maintenance option chosen over the cheaper one; it was the only
route. Recorded here so it is never reopened as though a trade-off
existed. Also recorded as *my* framing error: I offered two options
having checked that (a) was sensible, not that it was **available**.

This generalises into a standing constraint, held in
`docs/PROJECT_DEFINITION.md` §7.1.1 as **V-10**:

> `.github/workflows/**` is permanently outside this pipeline's reach.
> Every creation or edit of a workflow file is a repository-owner
> commit. The obligation on the agents is to prepare the exact file
> content under `docs/ci/` first, so the owner's step is always
> copy-and-commit and never design.

W-11 above is how this project honours that obligation day to day, and
W-10 is how it avoids having to invoke it at all.

#### 9.1.5 First Windows runs — what actually executed, and what the evidence says

Assessed 2026-08-13 by the Systems Engineer against run **`31723230235`**
(`fc23901`, the install commit) and run **`31724367652`** (`4a849b7`),
reading the job log and the published artifact rather than the job's
green tick. Runs are identical in shape; figures below are from
`4a849b7`, whose artifact is `windows-evidence-4a849b7…` (9190651619).

**The machine, as the run reported it (W-9 — read from this run, not
assumed):**

| Property | Value |
| --- | --- |
| Image | `win25-vs2026` 20260803.193.1 |
| OS | Microsoft Windows Server 2025 Datacenter 10.0.26100 |
| CPU | AMD EPYC 9V74, 2 cores / 4 logical, 2596 MHz max |
| RAM | 16 GB |
| Visual Studio | **2026** (v18.8 Enterprise) — **not VS 2022** |
| Compiler actually invoked | `MSVC 14.44.35207`, `PlatformToolset=v143`, `/std:c++17` |

**Per-step outcome:**

| Step (TP it feeds) | Job step result | What the evidence actually supports |
| --- | --- | --- |
| Build `Debug\|x64` (TP-900/901) | success | Solution and all three projects build clean, 0 warnings, 0 errors, under `v143` / MSVC 14.44 with no `/p:` beyond `Configuration` and `Platform` (W-8 held). |
| Build `Release\|x64` (TP-900/901/906) | success | As above; `x64\Release\SudokuSolver.exe` and `SudokuSolver.Tests.dll` produced; `CopySamples` copied all five fixtures beside the exe. |
| `vstest.console.exe` (TP-905) | **failed, exit 1** | **Nothing.** See defect **DW-1** below — no discovery list and no `.trx` were produced. |
| `dumpbin /dependents` (TP-506) | success | Import table of the delivered exe is **`KERNEL32.dll` and nothing else** — no `MSVCP140.dll`, no `VCRUNTIME140*.dll`. This is TP-506's own automatable clause, executed and clean. |
| Runtime procedures (TP-0xx/3xx/4xx/505) | NOT-RUN | `tests/windows/run-procedures.ps1` absent. Correct behaviour, not a pass (V-6). |
| Timing set (TP-500…504) | NOT-RUN | `tests/windows/run-timing.ps1` absent. Same. |

**W-2 held, and this is the check that mattered on day one.** The job
concluded `success` while one step had failed and two had not run, and
nothing anywhere in its output claimed a pass, a status or a
verification: the summary is a coverage table, it marked TP-905 and the
two script-driven sets as not executed, and it carries the line
*"Evidence only. Verdicts are the Test Engineer's."* No `status:*` or
`agent:*` label was touched by the workflow. A green tick on this
workflow means "the job ran", and the artifact is the thing to read.

##### Two defects in the workflow itself

- **DW-1 — the TP-905 step has never worked.** It passes both the test
  DLL *and* `/ListTests:"…\evidence\discovered-tests.txt"`. In
  `vstest.console.exe`, `/ListTests:<arg>` takes the **test container**
  as its argument, not an output path, so vstest treated
  `discovered-tests.txt` as a second test source and exited 1 with *"The
  test source file … was not found"*. Consequence: **no TP-905 evidence
  exists at any commit**, and §9.4 A-3 is *not* closed — contrary to the
  reasonable reading that the first green run had exercised it. Mine to
  own: it is my workflow text. Fix is two invocations — one
  `/ListTests:<dll>` for discovery, one plain run with `/Logger:trx` for
  execution.
- **DW-2 — the summary cannot say `FAIL`.** Each row is keyed only on
  whether an output file exists, so a step that ran and *errored* renders
  identically to one never attempted. W-5 specifies PASS / FAIL /
  NOT-RUN; the implementation emits two of the three. That is how DW-1
  read as a tidy `NOT-RUN` rather than as a broken step. It did not
  overstate anything — but understating a failure as an absence is the
  mirror image of the failure mode W-2 exists to prevent, and it is the
  row a reader is least likely to chase.

Neither is urgent and **neither is being sent to the owner on its own**
(W-11). DW-1's *evidence* can be produced today from
`tests/windows/run-procedures.ps1`, which the workflow already invokes
and which needs no permission (W-10); the workflow-side fixes are staged
in `docs/ci/windows-verification.yml` and batched for one install.

##### The finding that changes a requirement's reading: there is no VS 2022 on the runner

The image is `win25-vs2026`. `vswhere -latest` resolved to
`…\Microsoft Visual Studio\18\Enterprise`, and the build banner reads
*"Visual Studio 2026 Developer PowerShell v18.8.2"*. So the runner that
§9.1.3 wires the whole of Windows verification onto **does not have the
IDE named in `D-1`/`D-3` installed at all**.

Separating what that does and does not cost, because the two halves are
very different sizes:

- **The toolset half is intact.** The compiler actually invoked was
  `MSVC 14.44.35207` under `PlatformToolset=v143` — that is the *VS
  2022* toolset, shipped side-by-side inside the VS 2026 install. The
  binary the runner produces is a v143 binary, so the `Release|x64`
  build, the `/std:c++17` conformance and the TP-506 import table are
  evidence about the same artifact a client's VS 2022 would emit.
- **The IDE-load half is not.** "Opens in VS 2022 with no migration
  prompt" (TP-900) and "clone, open, press Build" (TP-901) are claims
  about the *VS 2022 solution loader*, and no run on this image can
  exercise it. `devenv.exe /Build` — the automation route §9.4 A-2
  proposed — is available, but it is VS **2026**'s `devenv`, so it tests
  the wrong loader. A-2 therefore does **not** fall out of the V-4 list;
  it narrows to exactly the loader clause, and needs a probe first.

The committed artifacts are still pinned to VS 2022 form and this is
already asserted by the Ubuntu-side clause of TP-900:
`SudokuSolver.sln` carries `Format Version 12.00` /
`# Visual Studio Version 17` / `VisualStudioVersion = 17.0.31903.59`,
and all three `.vcxproj` carry `PlatformToolset=v143` and
`WindowsTargetPlatformVersion=10.0`. Necessary, not sufficient: a VS
2026 build succeeding is *forward* compatibility, and the requirement
runs the other way.

**Next step on this, and it costs nothing:** the probe belongs in
`tests/windows/run-procedures.ps1` per W-10 — `vswhere -legacy -all
-products *` enumerating every VS instance on the image, printed into
the evidence. If a `17.x` instance turns out to be present, A-2 closes
by automation. If not, the finding is recorded and A-2 goes to the
Solutions Architect as a V-4 row with a measured reason. Either way it
is data, not an assumption, and it needs no owner action.

### 9.2 DELIV coverage after the Generate Code Base scaffold

State at branch `issue-5` @ `04b0269`, inspected by the Test Engineer
2026-08-07. "Executed" means the procedure's clause was actually run
against the tree, not read. **This table is the standing shape for any
partially-executed procedure** (V-6), not a one-off: a procedure with
unexecuted clauses gets a row here naming them.

Merged to trunk 2026-08-07 as **`85bab27`** (CI/CD, issue #5), which is
now in the Commit(s) column of all nine rows below. CI/CD re-ran the
repository-inspection clauses against the merge result and they hold
there too; the MSVC build, the VS 2022 solution load and Test Explorer
discovery remain unexecuted, per §9.1.

**Post-merge regression pass, `main` @ `4edbc6c`, Test Engineer
2026-08-07 — PASS, no regressions, no status movement in either
direction.** Recorded here because "we re-ran it and nothing moved" is
a result, and the next reader of this table should not have to wonder
whether the merge was ever re-checked. The load-bearing finding is that
`git diff 9636f45 4edbc6c -- src tests samples SudokuSolver.sln
.gitignore .gitattributes README.md` is **empty**: the merge changed
`docs/RTVM.md` §9 and nothing any DELIV procedure inspects, so every
row below re-confirms rather than re-derives. TP-902, TP-906 and
TP-903's inspection clauses were fully re-executed on trunk; TP-907's
fixture clause was re-run specifically because `.gitattributes` was
touched by the merge, and all five samples are still 90 bytes with zero
CR bytes; TP-900's executable clauses all hold. The outstanding column
below is unchanged — none of those clauses became reachable, and none
is a defect against `4edbc6c`.

**Windows evidence now exists for part of the "Still outstanding"
column — no status moves here on the strength of it.** Run
`31724367652` (`4a849b7`, §9.1.5) executed an MSVC `Debug|x64` and
`Release|x64` build of the committed solution, and `dumpbin
/dependents` on the delivered exe. That bears directly on RTVM-900,
RTVM-901, RTVM-906 and RTVM-506. Deliberately **not** actioned in this
table, for three separate reasons, each of which would be enough on its
own: the workflow issues evidence and never a verdict (W-2), the
verdict is the Test Engineer's and belongs to issues #21, #22 and #14,
and two of the four clauses are not in fact closed by that run — TP-900
and TP-901's outstanding clauses are about the *VS 2022 loader*, which
that image does not have (§9.1.5). RTVM-506's row is the one genuinely
moved forward: its `dumpbin` clause is executed and clean, leaving only
the clean-machine launch (§9.4 A-1).

| Req | Executed here and passed | Still outstanding |
| --- | --- | --- |
| RTVM-900 | `.sln` + three `.vcxproj` tracked in git; all six project files parse as XML; every `ClCompile`/`ClInclude` path exists; solution GUIDs match project GUIDs; `WindowsTargetPlatformVersion` = `10.0` in all three | TP-900's second sentence — the solution opening in VS 2022 with no "project unavailable" and no migration prompt |
| RTVM-901 | — | All of TP-901: clone, open, Build, on a machine that has never built this. Needs the README (RTVM-904) first |
| RTVM-902 | **All of TP-902.** No `packages.config` / `vcpkg.json` / `conanfile` / NuGet reference / vendored tree; the only paths outside the repo are `$(VCInstallDir)Auxiliary\VS\UnitTest\{include,lib}` (MSVC toolset) | — |
| RTVM-903 | **All of TP-903.** Zero console/stream/`argv` references under `src/SudokuCore/`; single bare `9` is `kGridSize`'s own definition; the core links into a test driver with no console-layer object file present | Re-confirm the link clause under MSVC rather than `g++`. Evidence, not verdict, is what changes |
| RTVM-904 | All seven **required sections** of `docs/SDD.md` §3.4 present as stubs — `Prerequisites`, `Build`, `Run`, `Input format`, `Exit codes`, `Samples`, `Tests`. (`README.md` has eight `#` headings; the eighth is the document title, which §3.4 does not require and #22 should not count) | All TP-904 content clauses — issue #22 |
| RTVM-905 | Test project present in the solution; both placeholder methods compile and pass under a `CppUnitTest.h` shim | TP-905's real clause — discovery and execution through Test Explorer / `vstest.console.exe`, plus the README command |
| RTVM-906 | **All of TP-906.** `stdcpp17` in both configurations of all three projects; `Debug\|x64` and `Release\|x64` are the only configurations anywhere; no `CMakeLists.txt` / `Makefile` / `meson.build` / other cross-platform build file | — |
| RTVM-907 | Fixture clause: all five `samples/*.txt` identical to their §6.1 fixtures, 90 bytes each, LF, no trailing blank line | The README clause — all five named with their expected outcome (rides with RTVM-904) |
| RTVM-506 | `/MT` `/MTd` set on `SudokuSolver` and `SudokuCore`; the test DLL's `/MD` does not touch the delivered exe (§9.3) | All of TP-506 — the clean-machine run |

**When a DELIV item reaches Verified.** Both of these, and nothing
less:

1. Every clause of its procedure has been executed and passed — on the
   real toolchain where the clause names one (§9.1, V-1). A clause run
   on a substitute toolchain is evidence, not execution.
2. CI/CD has reported the trunk commit and it is in the Commit(s)
   column.

Applying that to `85bab27`:

- **RTVM-902 and RTVM-906 are Verified.** TP-902 and TP-906 as written
  are pure repository inspection — every clause is a file or project
  setting, none of them needs Windows — and both were executed in full
  and passed, twice (Test Engineer @ `04b0269`, CI/CD on the merge
  result). Issue #21 should **not** re-litigate these two; its job for
  them is to confirm no regression, and to report it if there is one.
- **RTVM-900, RTVM-903 and RTVM-907 stay In Test.** Each has exactly
  one clause outstanding, named in its row above. RTVM-903's is the
  narrowest — the link demonstration ran under `g++`, not MSVC — but
  §9.1 does not make an exception for narrow, so it waits.
- **RTVM-901, RTVM-904, RTVM-905 and RTVM-506 stay In Implementation.**
  Part of what their procedure inspects is not built yet; the SHA
  records the scaffold they now sit on, not their completion.

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

**Status: draft, not agreed, and still not to be surfaced.** V-4
permits a client-acceptance pass only for clauses a hosted Windows
runner *genuinely* cannot execute, and V-5 requires the list to be
agreed in advance. This is my first-pass candidate list; each row
states the automation route I believe closes it, because the honest
version of this list is short. It is confirmed with the Test Engineer
against a real Windows job — several rows are expected to *leave* the
list at that point, and no row leaves this table for the client until
it has survived that.

**Second pass, 2026-08-13, against the first real Windows runs
(§9.1.5).** The list is still six rows and still goes nowhere. The
honest scorecard of the three rows that were expected to fall out:

- **A-3 did not close.** The reasonable expectation after a green first
  run was that `vstest.console.exe` had already exercised it. It had
  not — the step has never worked (defect DW-1), so there is no TP-905
  evidence at any commit. Closable without any owner action once
  `run-procedures.ps1` performs the discovery (W-10), but *not closed*
  until that evidence exists.
- **A-2 got bigger, not smaller.** The runner image has **no VS 2022 on
  it at all**; its `devenv.exe` is VS 2026's. The row narrows to the
  loader clause alone — the toolset half is genuinely covered, since the
  compiler invoked is the v143 / MSVC 14.44 toolset — but it now has a
  measured reason it cannot be automated on this image, which is exactly
  what a V-4 row is.
- **A-1 half-closed, as predicted and in the direction predicted.** Its
  `dumpbin` clause ran clean at `4a849b7`. The two halves are kept
  separate below because they are different sizes of ask.

Net: one row shrank, one row grew, one row that was expected to
disappear is still open. That is why the list waits for evidence rather
than for a plan.

| # | Clause | Why a hosted runner may not reach it | Proposed automation route before conceding it | Recommendation |
| --- | --- | --- | --- | --- |
| A-1 | **TP-506** — run the exe on a clean Windows machine with no VS, no redistributable, no build tools | Every hosted Windows image ships the full VS toolchain and the VC++ runtimes, so "runs where the runtime was never installed" cannot be demonstrated there — the negative is unobservable on the only machine we have | `dumpbin /dependents` asserting the import list is stock system DLLs only (`KERNEL32`, `USER32`, …) with no `MSVCP140.dll` / `VCRUNTIME140*.dll` — TP-506's own last sentence, and it is strong evidence | **Genuine V-4 item — confirmed 2026-08-13, and now down to one sentence.** The `dumpbin` clause is **executed and clean** at `4a849b7`: the delivered exe imports `KERNEL32.dll` and nothing else, with no `MSVCP140.dll` / `VCRUNTIME140*.dll`. That is near-conclusive and needs nothing from the client. The residue going to acceptance is only *"the exe launches on a machine where the VC++ runtime was never installed"* — the one thing no machine we can rent will ever demonstrate, because they all have it |
| A-2 | **TP-900** — the solution *opening* in VS 2022 with no "project unavailable" and no migration prompt | The prompt is modal GUI behaviour; a headless runner never renders it | `devenv.exe SudokuSolver.sln /Build "Debug\|x64"` uses the same solution loader as the IDE and fails or hangs where the IDE would prompt; combined with a toolset/`ToolsVersion` inspection this covers the substance | **Reopened and reshaped 2026-08-13 — the proposed route is dead as written.** The image is `win25-vs2026`: there is no VS 2022 installed, so `devenv.exe` is VS **2026**'s and drives the wrong loader. What *is* covered is the toolset half — the build ran on `PlatformToolset=v143` / MSVC 14.44, the VS 2022 toolset shipped side-by-side — so this row narrows to the IDE-load clause alone. **Next: the `vswhere -legacy -all` probe from `run-procedures.ps1`** (W-10, no owner action). If a `17.x` instance is on the image, this closes by automation; if not, it goes to the Solutions Architect as a V-4 row with a measured reason rather than a suspicion |
| A-3 | **TP-905** — tests appearing in **Test Explorer** | Test Explorer is a GUI surface | `vstest.console.exe` is the discovery and execution engine Test Explorer drives; if it discovers and runs both methods, the substantive claim holds | **Still not a V-4 item — but still open, 2026-08-13.** The first runs did *not* exercise it: the workflow's vstest invocation has never worked (defect DW-1, §9.1.5), so no discovery list and no `.trx` exist at any commit. Closes as soon as `run-procedures.ps1` runs `vstest.console.exe /ListTests:<dll>` plus a `/Logger:trx` execution and drops both in the evidence directory — agent-writable, no owner action, no permission (W-10). Do not record this row as closed until that artifact is in hand |
| A-4 | **TP-004…008** — the console-handle behaviour (`PeekConsoleInput`, `GetFileType` = console, an interactive-equivalent stdin held open) | A runner step has no interactive console attached: stdin is a pipe or `NUL`, so `GetFileType` never reports a console and the console path is never entered. TP-008's redirected half runs fine; TP-004/005/006's do not | Drive the exe under a **ConPTY pseudoconsole** (`CreatePseudoConsole`, available on Windows Server 2022) from a small harness, so the child genuinely sees a console handle. This is the same mechanism Windows Terminal uses and it is not exotic | **Undecided — needs a feasibility spike on #17** before it goes anywhere near the client. If ConPTY works this whole row disappears, and it is the largest row on the list. **2026-08-13: the spike is now actually possible** — there is a live Windows job to try it against, and the image is Windows Server 2025, where `CreatePseudoConsole` is long-established. The spike belongs in `tests/windows/run-procedures.ps1` (W-10). Worth doing on its own terms even if it fails: *"we drove the exe under a pseudo-console and here is precisely what it still could not observe"* is a far stronger thing to put to a client than *"consoles are hard"* |
| A-5 | **TP-500…504** — the timing set | Shared-tenant runner jitter against a ±1.0 s tolerance (§7 I-6) | W-7: three samples, Release build, all reported | **Not a V-4 item.** Run it; if the tolerance proves unholdable *with data in hand*, that is a requirements question for me, not a client-acceptance one. **2026-08-13: still NOT-RUN** — `tests/windows/run-timing.ps1` does not exist yet, and its absence is correctly recorded as NOT-RUN rather than as a pass. The machine it will run on is now known and modest — 2 physical cores / 4 logical, 2596 MHz, 16 GB (§9.1.5) — which is a reason to expect jitter, not a reason to pre-emptively widen §7 I-6 |
| A-6 | **TP-901** — build "on a machine that has never built this project" | — none; a fresh hosted runner satisfies this clause **better** than a client engineer's machine, which has VS configured and a warm state | n/a | **Not a V-4 item.** Recorded only to stop it being added later by association |

Nothing on this list is surfaced to the client until it is down to the
rows that survive A-2, A-3 and A-4's automation attempts — per V-5 that
is the Solutions Architect's step, and a two-row list is a decision
where a six-row one is a shrug.

**What has to happen before this list is sent (2026-08-13).** All three
are agent-side, all three live in `tests/windows/run-procedures.ps1`,
and none needs an owner action or a permission:

1. `vstest.console.exe` discovery + execution evidence → closes **A-3**.
2. `vswhere -legacy -all -products *` instance enumeration → closes or
   confirms **A-2**.
3. The ConPTY spike → closes or confirms **A-4**, the largest row.

On the evidence so far I expect the list that reaches the client to be
**A-1's launch clause, and possibly A-4**. Everything else should die by
automation.

### 9.5 DATA-IN coverage after the parser ([RTVM-100], issue #6)

State at branch `issue-6` @ `6d718e6`, tested by the Test Engineer
2026-08-13 — **PASS**, 95 assertions, 0 failures, under a `g++
-std=c++17` driver against `SudokuCore` only. Same table shape as §9.2
and the same V-6 rule: a procedure with unexecuted clauses gets a row
naming them, and no row here is Verified yet.

| Req | Executed here and passed | Still outstanding |
| --- | --- | --- |
| RTVM-100 | **All of TP-100.** `parseGrid(P-EASY)` gives `r1c1`=5, `r1c2`=3, `r1c3` empty, `r5c1`=4, `r9c9`=9, exactly 30 givens, `isComplete()` false; `toCompactString` round-trips to the 81-character `P-EASY` byte for byte with `0` as the empty character | Re-execution under MSVC / the VS test project (V-1: the `g++` run is evidence, not a verdict). Nothing else |
| RTVM-101 | TP-101's **parse clause** — `P-EASY`, `P-EASY-DOTS` and `P-EASY-MIXED` all parse to an identical grid, identical compact form, no `.` surviving into the grid | TP-101's **end-to-end clause** — "all three run end-to-end to the `S-EASY` grid with exit `0`". Not runnable until `Solver` (#8) and the output layer (#9) exist; the binary currently exits `1` with empty stdout on a valid puzzle, which is the stub state, not a defect. Plus the MSVC re-execution |
| RTVM-106 | TP-106's **parse clause**, all five positives (CRLF; LF; no trailing newline; two trailing blank lines and a 10th line `garbage`; three leading and two trailing spaces on line 3) and the negative case, which now matches §7 I-15 exactly: `IllegalCharacter`, `' '`, `first == {3,4}`, `line == 3`. Two Test-Engineer additions also pass — CRLF with no trailing newline, and tabs at both ends of line 6 | TP-106's **end-to-end clause** — the five positives are worded "expecting the `S-EASY` grid on stdout and exit `0`", which needs #8 and #9, and the negative's stderr wording needs [RTVM-102] (#10). Plus the MSVC re-execution |

**Re-run trigger.** RTVM-101 and RTVM-106 must have their end-to-end
clauses re-run once #8 and #9 are both merged, and RTVM-106's negative
case once #10 lands the wording. That is a real scheduled action, not a
caveat: whoever closes the later of #8/#9 should expect these two rows
back. Until then neither requirement goes past In Test even after CI/CD
reports the trunk SHA — the SHA records the parser they sit on.

**Merged to trunk 2026-08-13 —
`3bc1b2227d1081f5b24edbb3549d5081cbe90ef5` (`3bc1b22`).** CI/CD merged
`issue-6` (branch head `9fe0426`, one memory-only commit past the
`06ec659` reported here) `--no-ff` with no conflicts, and re-ran the
whole-program build and the TP-903 grep on the *merged* trunk content.
That SHA is now in the Commit(s) column for RTVM-100, RTVM-101 and
RTVM-106. **All three stay In Test**, including RTVM-100: §9.2's rule
takes two things for Verified, and while RTVM-100 now has its SHA, its
one remaining clause — execution under MSVC / the VS test project — is
exactly the kind of clause that kept RTVM-900/903/907 at In Test after
`85bab27`. TP-100 is a `Test`-method requirement whose home is the VS
test project, so a `g++` pass is evidence, not a verdict (V-1), and the
standing gap is #23. RTVM-101 and RTVM-106 additionally hold on their
end-to-end clauses per the re-run trigger above. Nothing here needs
re-executing when MSVC becomes available beyond the named clauses —
what has passed has passed.

**Regression on trunk, 2026-08-13.** CI/CD flagged this merge as
needing regression testing — it is the first trunk merge carrying real
feature code rather than scaffold — so RTVM-100/101/106 go back to the
Test Engineer against trunk before this issue closes. Result to be
recorded here; "no change required" is itself a result worth writing
down (per the §9.2 note), so an empty product-path diff gets stated
rather than assumed. Measured before the hand-off: trunk is two commits
past `3bc1b22` and both are agent-memory/lock files only
(`GET /compare/3bc1b22...main` → `.claude/**` exclusively), so the
`src/` and `samples/` trees on trunk are identical to the `6d718e6` the
95-assertion pass was taken on. The regression question is therefore
"did the merge disturb anything", not "does the parser still work" —
re-run TP-100/101/106's parse clauses plus the `ScaffoldTests`
(RTVM-903/905) set on a clean trunk checkout and that is the whole job.

**Regression result, 2026-08-13 — PASS. The merge disturbed nothing.**
Executed by the Test Engineer on a clean `main` checkout at `0996255`
(merge `3bc1b22`): 65 driver assertions plus the 2 `ScaffoldTests`
methods, 0 failures, `g++ -std=c++17 -Wall -Wextra -Wconversion
-Wpedantic` over `src/SudokuCore/*.cpp` only. Recorded here because "no
change required" is a result, not an absence of one:

- **The product-path diff across the merge is one README hunk.**
  `GET /compare/6d718e6...main` returns 13 files: ten under
  `.claude/agent-memory/**`, `docs/RTVM.md`, `docs/SDD.md` and
  `README.md`. `src/`, `tests/`, `samples/`, the `.sln`, both
  `.vcxproj`, `.gitattributes` and `.gitignore` on trunk are
  byte-identical to the `6d718e6` the 95-assertion pass was taken on.
  The README hunk is the trunk-side wording re-flow (`3497383`) that
  predates the branch — the same claim, re-wrapped, and TP-904's
  `0`/`.` clause still holds. RTVM-904 stays **In Implementation** and
  #22 owns it; the re-flow left a semicolon ending a clause the next
  line restarts with a capital, which is cosmetic, has no test hanging
  off it, and is #22's to tidy when it writes the section.
- **TP-100 — pass in full**, re-derived from §6.1 rather than carried
  over: 30 givens, the four spot-checked cells, `isComplete()` false,
  and an 81-character `toCompactString` round trip.
- **TP-101 parse clause and all five TP-106 positives — pass**, plus
  the Test Engineer's two additions (CRLF with no trailing newline;
  tabs at both ends of line 6).
- **TP-106's negative case — pass against the §7 I-15 wording as
  ruled**: `IllegalCharacter`, `' '`, `first == {3,4}`, `line == 3`,
  not `LineTooLong`. TP-105's narrowness confirmation re-run with it —
  `P-LONGLINE` still `LineTooLong` line 5 length 11, `P-MULTIFAULT`
  still the missing line. The exception is as narrow on trunk as it was
  on the branch.
- Standing checks re-run green: `ScaffoldTests` (RTVM-903/905) through
  the CppUnitTest shim, core-only link with no console object file (a
  live demonstration of the RTVM-903 split, not a grep of it), the
  TP-903 greps, the whole-program build, TP-907's five 90-byte LF
  fixtures and the `.gitattributes` pins, and RTVM-900's
  `git check-ignore`.
- **The TP-505-shaped adversarial set re-run unchanged**: empty input,
  1 MB single line (instant, `kLengthExceedsCap`), exactly 4096 bytes
  (exact length, boundary still off-by-one clean), 10 000 lines,
  embedded NUL, UTF-8 BOM, whitespace-only line, `\v`, `:`, all-dots,
  and the `S-EASY` round trip.
- **The end-to-end clauses of TP-101 and TP-106 were deliberately not
  re-litigated** — untouched by the merge and correctly outstanding
  under the re-run trigger above. **MSVC / Test Explorer remain
  unexecuted** (V-1, #23), as standing.

**Issue #6 closes at this point, and the three rows stay In Test.**
Issue state and requirement status are separate questions. §9.2's rule
takes two things for Verified — the trunk SHA *and* every clause of the
procedure executed — and `3bc1b22` supplies only the first: RTVM-100
still owes its MSVC / VS-test-project execution, and RTVM-101 and
RTVM-106 additionally owe their end-to-end clauses (#8, #9) and, for
RTVM-106's negative, #10's wording. Those are re-run triggers keyed to
*those* issues, not to this one, so closing #6 loses nothing; promoting
the rows to make the close-out look tidy would delete the only record
that half of two procedures never ran.

**Fault data already correct, ahead of [RTVM-102].** Detection of shape
and illegal-character faults is inseparable from accepting a valid
grid, so the parser already produces populated `InputFault` objects on
those paths and the Test Engineer verified their *data* (not their
wording): `P-SHORT` → `MissingLine` line 9; `P-LONGLINE` → `LineTooLong`
line 5 length 11; `P-SHORTLINE` → `LineTooShort` line 5 length 7;
`P-BADCHAR` → `IllegalCharacter` `X` at `r1c1`; `P-MULTIFAULT` → shape
only; `P-MULTIFAULT-9` → illegal character only. RTVM-102/103/105 stay
**Approved** rather than moving — their procedures are about the
*message on stderr and the exit code*, and no message exists yet. #10
owns those, plus RTVM-104 contradiction detection, which is explicitly
not implemented (a well-shaped but self-contradictory puzzle currently
reaches the solver).

**§7 I-13 is real, and its boundary is clean.** A 1 MB single-line
input returns instantly with `LineTooLong` and
`observedLength == kLengthExceedsCap`; a line of exactly 4096 bytes
reports the exact length 4096. The `kLengthExceedsCap` sentinel is
`kMaxLineBytes + 1` and is now specified in `docs/SDD.md` §2.5 — #10's
`Messages` renders it as "more than 4096 characters" per I-13 and must
never print the sentinel as a number.

### 9.6 DATA-OUT coverage after the result and fault vocabulary ([RTVM-300], issue #7)

State at branch `issue-7` @ `130cc8b`, tested by the Test Engineer
2026-08-13 — **PASS**, 14 tests, 0 failures, under a `g++ -std=c++17
-Wall -Wextra -Wconversion -Wpedantic -Wshadow` driver linked against
`SudokuCore` **only** (no console object file, which makes that run a
live demonstration of the RTVM-903 split rather than a grep of it).
Same table shape and same V-6 rule as §9.2 and §9.5: a procedure with
unexecuted clauses gets a row naming them, and no row here is Verified
yet.

| Req | Executed here and passed | Still outstanding |
| --- | --- | --- |
| RTVM-300 | TP-300's **type-level half**, in full. The five factories yield five distinct outcomes; every report's payload matches the §2.4 invariant table (`hasGrid()` ⇔ `outcomeCarriesGrid()`, `hasFault()` ⇔ `outcomeCarriesFault()`, never both); asking for a payload the outcome does not carry returns an empty stand-in rather than undefined behaviour (RTVM-505). "Never none" and "never two" are unrepresentable — enforced by `static_assert` plus two `default`-less switches, and confirmed by mutation (below) rather than by a green build | TP-300's **whole-run half** — "drive the application once for each of the five fixture classes … expect exactly one outcome and the five to be distinct". Not runnable until every outcome exists end to end; it is executed under [RTVM-405] (#18), as this issue's description already stated. Plus the MSVC re-execution (V-1) |
| RTVM-301 | TP-301's **property**, against the §6.1 `S-EASY` solution fixture: all `kCellCount` cells of both the `Solved` and the `SolvedNotUnique` report are digits `1..kGridSize`, no empty cell. The falsifiable half passes too — one blanked cell, one out-of-range digit, and the unsolved `P-EASY` grid each report `false`. The Test Engineer independently re-derived the fixtures: `kSolvedEasy`/`kPuzzleEasy` match §6.1 byte for byte, `P-EASY` has exactly 30 givens, and `S-EASY` is a genuine solution (every row, column and box a permutation of 1–9, consistent with every `P-EASY` given) | TP-301 **as worded** names the *solved results* of `P-EASY` and `P-NONUNIQUE`, which need the solver (#8) and non-uniqueness detection (#12). The assertion does not change when they land — the tests take a real `solve()` result and the expectations stay as they are. Plus the MSVC re-execution |
| RTVM-302 | TP-302's **fault-object clauses**. The `P-CONTRA-ROW` fault is asserted as data — `RowDuplicate`, line 1, digit `5`, cells `r1c1` and `r1c7`, matching TP-104 case 1 exactly. "No pre-formatted English" is asserted structurally rather than by inspection: a structured binding names every member of `InputFault`, all of which are enums, integers, a `char`, `CellRef`s or a `uint32_t`, and the single `std::string` is `path` (empty for any parser-produced fault). 1-based conversion happens in one function per §7 I-16; an out-of-grid coordinate is *not applicable* rather than wrapped (RTVM-505) | TP-302's **parse-driven half** — "parse `P-CONTRA-ROW`" needs RTVM-104 contradiction detection, which is #10's and still `TODO` in `Parser.cpp`. The fault object asserted here **is** the expectation #10 must produce, so that test grows a `parseGrid` call and no new expectations. Plus the MSVC re-execution |

**Re-run trigger.** RTVM-301 must have TP-301 re-run against real
`solve()` results once #8 and #12 are merged, and RTVM-302 must have
TP-302 re-run against a real `parseGrid` once #10 is merged. RTVM-300
does not close until #18 executes TP-300's whole-run half. All three
therefore stay **In Test** after CI/CD reports the trunk SHA — the SHA
records the vocabulary they sit on, per §9.2's two-part Verified rule.

**A green build is not evidence when the assertion is a
`static_assert`.** Most of RTVM-300 is asserted at compile time, and a
deleted or vacuous `static_assert` compiles just as happily as a
correct one. Both the Software Engineer and the Test Engineer therefore
mutated a throwaway copy of the tree and confirmed each guard fires:
reverting the `+1` in `cellRefFromZeroBased` fails 3 tests; dropping
the digit-range check in `hasCompleteGrid` fails 1; inserting a sixth
enumerator, appending one, adding a `message` field to `InputFault`,
adding a public default constructor, or making the `Outcome`
constructor public each fail the **build**; a factory that forgets its
grid fails 2 tests; and an `outcomeCarries*` that misreports `Aborted`
fails 1. **This is the standing rule for any compile-time invariant on
this project: state the mutation and its observed effect, or the clause
is unverified.** It costs one paragraph in the test report and it is
the only thing separating a real guard from a comment. (This is a
verification-recording convention, not a new V-rule — V-1…V-7 are the
Solutions Architect's and are unchanged.)

One recorded non-defect, so it is not re-raised: a **private** default
constructor does not trip `!std::is_default_constructible_v`, because
the trait is evaluated from outside the class. That mutation only means
anything when the constructor is added to the `public:` section.

**Merged to trunk 2026-08-13 —
`668f9a4c1c2c82fe955f751b7a829039ed11fae8` (`668f9a4`).** CI/CD merged
`issue-7` (branch head `f5d8577`, two memory-only commits past the
`6aadb90` this section's status changes were written at) `--no-ff`, and
re-ran the whole-program build, the 14-test unit suite (core-only link)
and the TP-903 greps on the *merged* trunk content rather than on the
branch. That SHA is now in the Commit(s) column for RTVM-300, RTVM-301
and RTVM-302. **All three stay In Test**, exactly as the re-run trigger
above said they would: §9.2's two-part rule needs the SHA *and* every
clause executed, and each of these three still has a clause the current
feature set cannot reach (#18, #8/#12, #10 respectively), on top of the
standing MSVC gap (V-1, #23). The SHA records the vocabulary they sit
on; it does not promote the status.

**The merge needed a doc conflict resolved, and the rule this section's
own handoff gave was stale.** That handoff said "for `docs/RTVM.md` and
`docs/SDD.md`, take `issue-7`'s version", on the grounds that it was a
strict superset of #6's *pending branch*. By merge time #6 had landed
and trunk had gained the `3bc1b22` SHAs in the Commit(s) column for
RTVM-100/101/106 plus §9.5's merge-and-regression paragraphs — none of
which existed on `issue-7`. Taking the branch wholesale would have
silently **reverted the trunk SHAs this matrix exists to record.** CI/CD
resolved it per hunk instead (trunk for the RTVM-100/101/106 rows and
§9.5; branch for §7 I-16, this §9.6 and the DATA-OUT status changes) and
verified against both parents. `docs/SDD.md` auto-merged clean and was
genuinely a superset. Confirmed on trunk while recording this SHA:
RTVM-100, RTVM-101 and RTVM-106 still read `3bc1b22`, and §9.5 is
intact. **Standing rule from this:** a "take my branch's version"
instruction is scoped to the trunk that existed when it was written, so
it expires the moment anything else merges. State the *reason* the
branch wins (what it adds) rather than the verdict, so whoever merges
can re-derive it against the trunk actually in front of them.

**Regression on trunk, 2026-08-13.** CI/CD flagged this merge as needing
regression testing — feature code onto trunk plus a hand-resolved doc
conflict that touched rows belonging to #6's requirements as well as
this issue's. Measured before the hand-off, so the Test Engineer is not
guessing at scope: trunk is two commits past `668f9a4` and
`GET /compare/668f9a4...main` returns `.claude/agent-memory/cicd/**`
only. The `src/`, `tests/`, `samples/` and `.vcxproj` trees on trunk are
therefore byte-identical to the `130cc8b` the 14-test pass was taken on.
The regression question is **"did the merge disturb anything"**, not
"does the vocabulary work" — the whole job is: re-run the 14 tests
(`SolveReportTests`, `InputFaultTests`, `ScaffoldTests`) on a clean
trunk checkout with the core-only link; re-run TP-100/101/106's parse
clauses, since the conflict resolution sat on their rows; and confirm by
inspection that RTVM-100/101/106 read `3bc1b22` and RTVM-300/301/302
read `668f9a4` in the Commit(s) column with §9.5 and §9.6 both present
and un-truncated. Mutation evidence is **not** required on a regression
pass — the guards were mutation-checked at `130cc8b` and the code has
not changed. "No change required" is itself a result worth writing down
here, so an empty product-path diff gets stated rather than assumed.

**New core API adopted into the SDD.** `outcomeCarriesGrid`,
`outcomeCarriesFault`, `SolveReport::hasGrid`/`hasFault`/
`hasCompleteGrid`, `CellRef::isApplicable`, `CellRef` equality, and
`cellRefFromZeroBased` were added at [RTVM-300] and flagged, the same
route `ParseResult` and `toCompactString` took. All are now specified
in `docs/SDD.md` §2.4/§2.5 as delivered — no rename, no signature
change. The §2.3-vs-§2.5 contradiction the same handoff raised is ruled
in §7 **I-16** and both SDD clauses are reworded to match.

**Regression result, 2026-08-13 — PASS. The merge disturbed nothing.**
Executed by the Test Engineer on a clean `main` checkout at `9844fd7`
(merge `668f9a4`). Recorded here because "no change required" is a
result, not an absence of one:

- **The product-path diff across the merge is empty.**
  `GET /compare/668f9a4...main` returns `docs/RTVM.md`,
  `.github/workflows/agent-relay.yml` and agent-memory paths only —
  `src/`, `tests/`, `samples/`, the `.sln` and all six project files on
  trunk are byte-identical to the `130cc8b` the original pass was taken
  on. That is stated rather than implied, per the scoping note above.
- **14 of 14 unit tests pass** (`SolveReportTests` 7,
  `InputFaultTests` 5, `ScaffoldTests` 2), linked against
  `src/SudokuCore/*.cpp` **only** with no console object file — the run
  re-demonstrates the RTVM-903 split rather than asserting it. Clean
  build, no warnings. No mutation evidence was required or produced, as
  directed: the guards were mutation-checked at `130cc8b` and the code
  has not changed since, so re-deriving M1–M9 would re-test the feature
  rather than the merge.
- **TP-100 / TP-101 / TP-106 parse clauses re-run — 26 checks, 0
  failures.** In scope because the hand-resolved conflict sat on those
  rows. §7 **I-15** still holds exactly as narrow as ruled: interior
  whitespace reports `IllegalCharacter` at `{3,4}`, while `P-LONGLINE`
  still reports `LineTooLong` and `P-MULTIFAULT` still reports the
  missing line. I-16 landing on adjacent code did not widen it.
- **Doc inspection confirms the per-hunk resolution held.**
  RTVM-100/101/106 still read `3bc1b22`; RTVM-300/301/302 read
  `668f9a4`; all six are In Test; §9.5 and §9.6 are both present and
  un-truncated; §7 I-15 and I-16 are both in the table.
- Standing checks re-run green: whole-program build, TP-903 greps,
  TP-907 sample sizes and `.gitattributes` pins, RTVM-900's
  `git check-ignore`, project-file XML and `Include`-path resolution,
  and a programmatic re-derivation of the §6.1 fixtures.
- **MSVC / Test Explorer remain unexecuted** (V-1, #23), as standing.

**Issue #7 is closed at this point on client instruction** ("no
regression testing on issue-7 branch — submit, merge and close this
out", 2026-08-13); the regression pass above had already been executed
and returned clean, so nothing was skipped to close it. **RTVM-300,
RTVM-301 and RTVM-302 remain In Test with `668f9a4` recorded**, and
closing the issue does not promote them: §9.2's two-part rule still
wants the outstanding clauses executed. The re-run trigger above is the
live mechanism — #18 for TP-300's whole-run half, #8/#12 for TP-301 as
worded, #10 for TP-302's parse-driven half — and those rows return to
this matrix as each lands, independently of #7's state.

**Documentation drift carried into #8** (observation, no defect, no
test hangs off it): `src/SudokuCore/Grid.h` still comments that "the
1-based `r<row>c<col>` form required by RTVM-105 is produced only in the
output layer." Under §7 **I-16** that is now the wrong reading — the
`+1` happens at fault construction in `cellRefFromZeroBased()` and
`Messages` does no arithmetic. `Grid.h` was not touched by #7, so the
comment is left for whoever next opens the file (#8 is the likely one)
rather than being changed on trunk outside a feature branch. Behaviour
is unaffected either way.

### 9.7 CORE coverage after the solver core ([RTVM-200], issue #8)

State at branch `issue-8` @ `05f7466` (product commit `c662bb1`),
tested by the Test Engineer 2026-08-13 — **PASS**, 19 tests, 0
failures, at both `-O0` and `-O2`, under a `g++ 13.3.0 -std=c++17
-Wall -Wextra -Wpedantic -Wshadow` driver linked against `SudokuCore`
**only** (no console object file — again a live demonstration of the
RTVM-903 split rather than a grep of it). Same table shape and same
V-6 rule as §9.2, §9.5 and §9.6: a procedure with unexecuted clauses
gets a row naming them, and no row here is Verified.

| Req | Executed here and passed | Still outstanding |
| --- | --- | --- |
| RTVM-200 | TP-200's **original two cases in full**. `P-EASY` → `S-EASY` and `P-HARD17` → `S-HARD17`, byte-identical to §6.1; for both, all 81 cells in 1–9, every row/column/box a permutation of 1–9, every given unchanged in place. The checks are falsifiable, not merely green: a moved `r1c1` given, a blanked cell, a duplicated digit and an unsolved grid are each rejected, and `nodesExplored() > 0` rules out a hard-coded answer. Fixtures independently re-derived from §6.1 rather than from the test header — all four match byte for byte, `P-EASY` has 30 givens, `P-HARD17` has 17, and each solution is a genuine solution consistent with every given. Ten repeat solves of `P-HARD17` are byte-identical (determinism). Beyond the procedure, a randomised cross-check against an independently written oracle: **60/60 uniquely-solvable puzzles returned `Solved` with exactly the oracle's grid**, 33 of them requiring real backtracking | **The new `P-SEARCH` clause** — added to TP-200 by this update and therefore not run in the #8 pass; it needs a fixture and one test method in `tests/SudokuSolver.Tests/`. Executed at **#11** (see the re-run trigger below). Plus the standing **MSVC / VS test-project re-execution** (V-1, #23) — the `g++` pass is evidence, not a verdict |

**The coverage gap this section exists to record, and what was done
about it.** Both TP-200 fixtures solve at `nodesExplored == 1`:
constraint propagation alone finishes them, and the MRV
branch/backtrack half of `docs/SDD.md` §1.5 never runs. The Test
Engineer found this, and it is a genuine hole in the *procedure*, not
in the requirement or the code — TP-200 asks about the answer, not the
route, so it passed correctly. Two consequences were confirmed by
mutation, on a throwaway copy of the tree:

| Mutation of `Solver.cpp` | TP-200 as it stood |
| --- | --- |
| Row elimination dropped from `assign` | **FAILS** — the procedure is falsifiable |
| Candidates tried in **descending** digit order | passes — undetectable |
| Hidden singles removed entirely | passes, ~5× slower |
| Box elimination dropped | passes — the hidden-single sweep re-imposes it |

The fix is **additive, and this test iteration is not cancelled**: the
#8 pass verified TP-200 as written and stands. TP-200 now carries a
third case, `P-SEARCH` (§6.1) — dug from `S-EASY`, 25 givens, uniquely
solvable, and *not* solvable by naked and hidden singles alone — with
an added assertion that `nodesExplored() > 1`. Because it was dug from
`S-EASY` its expected output is a fixture that already exists and is
already independently verified, so the new clause adds no new expected
value to get wrong. Verified against the delivered solver at `c662bb1`
before being written here: `P-SEARCH` → `Solved`, grid equal to
`S-EASY`, 5 nodes. **The code is not suspected and needs no change** —
only the test project gains a fixture and a method.

**Ascending candidate order remains unevidenced by test.** It is
normative in §1.5 because RTVM-202 and RTVM-401 depend on "the first
solution found" being reproducible, it is implemented as written
(`Solver.cpp`), and it has been confirmed by reading — but no procedure
here can detect it, since a uniquely-solvable puzzle has the same
answer whatever order the digits are tried in. **TP-202 (#12) is the
only place it becomes provable**, and that is stated so nobody later
mistakes RTVM-200's pass for evidence of it. `P-SEARCH` does not close
this either: it proves a branch was taken, not which branch was taken
first.

**Re-run trigger.** TP-200's `P-SEARCH` clause is executed at **#11**
([RTVM-201]) — the next issue to touch `tests/SudokuSolver.Tests/
SolverTests.cpp`, already scoped as tests against existing code, so the
clause costs one fixture and one method there rather than a new build
of the solver. If #12 reaches the file first, either may carry it; what
must not happen is RTVM-200 reaching Verified without it. RTVM-200
therefore stays **In Test** after CI/CD reports the trunk SHA, on two
counts (the `P-SEARCH` clause and V-1), per §9.2's two-part rule.

**Not claimed by this issue, and deliberately so.** The zero- and
two-solution exits of the same search loop already map to `NoSolution`
and `SolvedNotUnique`, because they are exits of one search rather than
separate code — but RTVM-201 (#11) and RTVM-202 (#12) keep their own
procedures and their own status. Those two issues are correctly scoped
as **tests against existing code**, not as further implementation.
Likewise the §2.6 poll shape landed early and was smoke-checked
(`pollNodeInterval == 0` disables polling with no hang and no division;
`onPoll` returning `false` yields `Outcome::Aborted`), but **RTVM-203
and RTVM-204 are not verified by that** — #16 owns them. RTVM-500 is
untouched: for reference only, at `-O0`, `P-EASY` 67 µs, `P-HARD17`
311 µs, `P-BLANK` 1.5 ms and Inkala/Platinum-Blonde-class adversarial
grids 2–26 ms, i.e. four orders of magnitude inside the 10 s budget —
but #15 proves it on the §6.3 reference machine, and margins measured
on a Linux runner are not that. `options.minSolveDuration` is carried
through the API and honoured by nobody yet (`TODO(RTVM-507)`), which is
#13's, and is what keeps that issue additive.

**§9.5's re-run trigger has *not* fired.** It names the later of #8 and
#9 for RTVM-101's and RTVM-106's end-to-end clauses; #9 is still
`status:on-hold`, and the built console binary still exits `1` with
empty stdout *and* empty stderr on a valid `P-EASY` — that is the stub
state of the output layer, not a solver regression. Those clauses stay
outstanding and return at #9.

**SDD §1.5's node-state size is reconciled here, no defect.** §1.5
specified undo by restoring a saved copy of the node state at "≈216
bytes"; the delivered node also carries a `std::array<Digit,
kCellCount>` of assigned digits, so ≈300 bytes. The reason is sound and
was declared by the Software Engineer rather than discovered: a
one-bit-per-digit candidate mask cannot distinguish *assigned* from
*one candidate remaining, not yet propagated*, and the report has to
emit digits. At maximum depth 81 that is ~50 KB of stack — still a
rounding error against RTVM-500, and no observable behaviour changes.
`docs/SDD.md` §1.5 is updated to describe what was delivered, so the
design record and the code agree; this is a documentation
reconciliation, not a change request.

**Documentation drift, still open, carried forward to #9/#11.**
`src/SudokuCore/Grid.h` still comments that the 1-based `r<row>c<col>`
form "is produced only in the output layer", which §7 **I-16** has
superseded. #8 did not open `Grid.h`, so it is passed on again rather
than changed on trunk outside a feature branch. Behaviour is unaffected
either way, and no test hangs off it.

#### 9.7.1 Merge to trunk, and the scope of the regression pass

`issue-8` was merged to `main` by CI/CD on 2026-08-13 as
**`fdd9cea`** (`fdd9ceaa10e2c75205d87dab7ddff11417c9133c`), a `--no-ff`
merge commit; that SHA is now RTVM-200's Commit(s) value. Two SHA
reconciliations, recorded so this thread and the history agree: the
merged branch head was `bf6cbb9`, two commits beyond the `e3d5459`
named in the hand-off (the extra two are lock releases and an agent
memory file — nothing product-bearing), and `git log <merge-base>..main`
was empty, so the merge-note hunk instructions had nothing to guard
against and the merge was clean with no manual selection.

**RTVM-200 remains In Test, and the SHA does not change that.** §9.2's
rule takes two things; the SHA supplies one. The `P-SEARCH` clause
(#11) and the MSVC re-execution (V-1, #23) are both still outstanding,
so the re-run trigger above stands unchanged.

**Regression scope, measured rather than assumed.**
`compare/fdd9cea...main` returns three files, all under
`.claude/agent-memory/cicd/`, and `compare/bf6cbb9...main` returns the
same three. **No path under `src/`, `tests/`, `samples/` or `docs/`
differs between the branch tip the PASS was taken on and trunk.** The
regression question is therefore "did the merge disturb anything?" and
not "does the solver work?" — the latter was answered at `bf6cbb9`
and stands. What that asks for concretely: build the merged trunk and
re-run the full unit suite (19 tests expected, the five `SolverTests`
methods plus the 14 pre-existing), confirm `SolverTests.cpp` is still
registered in both the test `.vcxproj` and its `.filters`, and confirm
the five `samples/*.txt` are still 90 bytes each. As established in §9.6, **mutation
evidence is not required on a regression pass** over code that has not
changed; re-deriving it re-tests the feature rather than the merge.
The `P-SEARCH` clause is *not* in scope here either — it belongs to
#11, which owns the fixture and the method.

**Correction to the scope measurement above.** The Test Engineer
re-derived it rather than taking it on trust and found **five** changed
files, not three: the two extras are `docs/RTVM.md` and a
`systems-engineer` memory file from `e294cff`, which landed *after* the
paragraph above was written. The conclusion is unchanged — the
`docs/RTVM.md` diff is exactly two hunks (RTVM-200's Commit(s) cell, and
§9.7.1 itself), **§6.1 is untouched**, and no path under `src/`,
`tests/` or `samples/` differs — but the lesson is recorded rather than
quietly patched: a "files changed since X" figure quoted in a hand-off
must be taken *after* the quoting agent's own push, or it is stale by
one commit the moment it is written. Re-derivation on receipt is what
caught it, and is why the receiving role should keep doing it.

#### 9.7.2 Post-merge regression pass on trunk — result

Executed by the Test Engineer on trunk `main` @ `e294cff` (merge commit
`fdd9cea`), 2026-08-13 — **PASS**. This re-confirms the `bf6cbb9` pass
on the merged tree; it does **not** extend it, and no clause outstanding
before the merge is closed by it.

| Check | Result |
| --- | --- |
| Full unit suite on merged trunk, `-O0` and `-O2` | **19 discovered, 19 passed, 0 failed**, identical at both levels. `SolverTests` 5, `SolveReportTests` 7, `InputFaultTests` 5, `ScaffoldTests` 2. Driver **auto-generated by scanning `TEST_CLASS`/`TEST_METHOD`**, so a test silently dropping out of the tree shows up as a lower count rather than as a green run — the count matches the Software Engineer's, CI/CD's and the Test Engineer's independent measurements |
| Core-only link | Test driver linked against `src/SudokuCore/*.cpp` **only**, no console objects — RTVM-903's layering demonstrated by the link succeeding, not grepped |
| Whole-tree build | Core + `src/SudokuSolver/*.cpp` compiles and links clean at `-O2`, zero warnings under `-Wall -Wextra -Wpedantic -Wshadow`. Trunk builds as a whole, not just the tested subset |
| VS project registration | Generalised rather than spot-checked: **no** `.cpp`/`.h` under `tests/` is unregistered, all six `.vcxproj`/`.filters` parse as XML, and every `Include` in all six resolves on disk. This is the one failure mode a `g++` run cannot otherwise see — an unregistered file compiles here and then never runs under MSVC |
| Samples | All five `samples/*.txt` still 90 bytes, each re-extracted from §6.1 and compared byte for byte — 5/5 match, all LF, no CRLF. `.gitattributes` still pins `samples/*.txt text eol=lf` and the three VS file types to CRLF |
| Fixture header | `P-EASY`, `S-EASY`, `P-HARD17`, `S-HARD17` re-derived from §6.1 (not read side by side) and present verbatim in `tests/SudokuSolver.Tests/TestFixtures.h` |
| RTVM matrix SHA audit | Standing practice after any merge touching `docs/RTVM.md`, because a document taken wholesale silently deletes the trunk SHAs the matrix exists to record. **No SHA lost**: RTVM-100/101/106 `3bc1b22`, RTVM-300/301/302 `668f9a4`, the DELIV set and RTVM-506 `85bab27`, RTVM-200 `fdd9cea`. §9.1–§9.7.1 all present and un-truncated |

**Scope held to, and what that deliberately excludes.** No mutation
evidence was re-derived (§9.6's rule — the code has not changed, so
re-deriving it re-tests the feature rather than the merge; the
`bf6cbb9` evidence stands). `P-SEARCH` was **not** run, in passing or
otherwise — it belongs to #11, and running it outside #11's procedure
would not credit RTVM-200 in any case. No Verified item was
re-litigated.

**No status change follows from this pass, and that is the finding, not
an omission.** A regression pass answers "did the merge disturb
anything?"; it adds no clause coverage, so §9.2's two-part rule is
untouched. **RTVM-200 remains In Test** on the same two counts as
before: the `P-SEARCH` clause (#11) and the MSVC / VS test-project
re-execution (V-1, #23). Commit(s) stays `fdd9cea`.

**Carried forward unchanged, checked rather than assumed.** The built
console binary on trunk still exits `1` with empty stdout *and* empty
stderr on a valid `P-EASY` — the unchanged stub state of the output
layer, **not** a regression, and confirmed on the merged tree rather
than inferred from the diff. §9.5's re-run trigger for RTVM-101 and
RTVM-106 therefore still has not fired (it names the later of #8 and
#9; #9 is still `status:on-hold`), and `src/SudokuCore/Grid.h`'s
pre-I-16 comment is still adrift, passed to #9/#11 again. One
additional observation from the pass, recorded but **not** crediting
anything: `git check-ignore` on the `.sln` and every `.vcxproj` returns
nothing ignored, which is relevant to RTVM-900 — #21 owns that
inspection and this does not stand in for it.

**Issue #8 closes here.** RTVM-200's remaining path to Verified runs
through #11 (the `P-SEARCH` clause) and #23 (V-1 / MSVC), in that
order; neither is reopened as work on this issue.

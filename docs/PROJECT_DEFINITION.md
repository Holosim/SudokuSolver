# Project Definition

<!--
Owned by the Solutions Architect. Every item below is tagged
[CONFIRMED] (stated directly by the client) or [PROPOSED] (a
recommended default, not yet a decision). Nothing may be built
against a [PROPOSED] item — flip it to [CONFIRMED] once the client
has actually responded, before handing off to the Systems Engineer.
-->

> ## ✅ STATUS: APPROVED — SCOPE DEFINED, CLEARED FOR HANDOFF
>
> The client confirmed scope by editing this document directly (commit
> `a773755`): every stakeholder need marked **[CONFIRMED]**, the input and
> output decisions accepted as proposed, `D-7` answered (**C++17, x64,
> Visual Studio only**), and one scope addition made to `SN-5` (a
> long-running solve must prompt the user and let them stop it — see §4.4).
>
> Every item in this document is now **[CONFIRMED]** and may be built
> against. If a later decision changes, the Solutions Architect updates this
> document, logs it in §8, and notifies the Systems Engineer — scope does not
> change by side conversation.
>
> **Revised 2026-08-07** (client, issue #1): the long-solve timings in §4.4
> changed — budget **10 s**, first prompt **15 s**, repeat **every 10 s** — and
> the solver must **keep working while a prompt is up**. See §8. §4.4.1 records
> the client's architecture-discovery question about how the interrupt is
> realised; that one is the Systems Engineer's to answer, not scope's.

## Mission Statement

A Windows console application that takes a standard 9×9 Sudoku puzzle and
returns the solved grid — quickly, legibly, and with a clear, specific answer
when a puzzle cannot be solved — delivered as a Visual Studio 2022 solution the
client's own engineers can open, build, and extend.

## Value

- The user gets a correct, complete grid without solving it by hand.
- The user is never left guessing: every run ends in a stated outcome (solved,
  not unique, invalid, unsolvable, aborted) and a matching exit code.
- The user is never trapped waiting — a long solve announces itself and can be
  stopped (§4.4).
- Scripts can drive it unattended and branch on the result (ST-4).
- The client owns a maintainable codebase, not just an executable (§6).

## Stakeholders and Needs

Stakeholders are listed in §"In scope for MVP" (`ST-1`…`ST-4`); the numbered
stakeholder needs `SN-1`…`SN-8` follow in the same section and are the IDs the
RTVM traces against. They are kept in one place there rather than duplicated
here, so they cannot drift apart.

## MVP Definition

<!-- Work this out through the 5 W's interview (see
     solutions-architect.md) — don't fill it in from assumption. -->

| # | Value | Delivered by |
|---|---|---|
| V1 | The user gets a correct answer without doing the work by hand | Core solver |
| V2 | The user is never left guessing whether the program worked | Explicit success / invalid / unsolvable outcomes, and a progress prompt on a long solve (§4.4) |
| V3 | The user can get a puzzle *into* the program without friction | Input method (§4.2) |
| V4 | The client's own engineers can extend the program later | Deliverable requirements (§6) |
| V5 | The user is never trapped waiting on the program | Abortable solve (§4.4) |

- **Target platform:** Windows, console application, x64
- **Language / stack:** C++17, stock Visual Studio 2022 toolchain, standard
  library only — no third-party dependencies, no CMake (§6, D-3/D-7)
- **Output format and delivery:** Pretty-printed 9×9 grid on stdout, diagnostics
  and progress prompts on stderr, outcome signalled by process exit code
  (`0`/`1`/`2`/`3`); delivered as a committed, openable VS 2022 solution


## Scope

### In scope for MVP

| ID | Stakeholder | Need | Notes |
|---|---|---|---|
| ST-1 | **End user** (puzzle solver) | Enter a puzzle, get the solved grid back, legibly | Assumed non-technical in domain terms but comfortable with a console window |
| ST-2 | **Client engineering team** (maintainer) | Open the solution in VS 2022, understand it, extend it | Drives §6, not §5 |
| ST-3 | **Client sponsor** | A demonstrable, finished, self-contained Windows application | Drives "it must actually ship and run", i.e. no external runtime dependencies |
| ST-4 | **Automated / scripted caller** | Invoke non-interactively and branch on the result | **[CONFIRMED]** — exit codes are a requirement (§4.3) |


<!-- What's actually being built in this first pass. -->

Numbered here because the RTVM traces every requirement back to one of these
(`SN-<n>`, per `docs/RTVM.md` §1). All **[CONFIRMED]**.

| ID | Stakeholder need |
|---|---|
| SN-1 | The user can supply a Sudoku puzzle to the application |
| SN-2 | The application solves any valid, uniquely-solvable standard 9×9 puzzle |
| SN-3 | The user receives the solved grid in a legible form |
| SN-4 | The application tells the user clearly when a puzzle is malformed, contradictory, or unsolvable, rather than failing silently or crashing |
| SN-5 | The application returns a result fast enough to feel immediate; and if a solve does run long, it prompts the user intermittently so they can stop it rather than waiting on an apparently hung program |
| SN-6 | The application runs on Windows as a console application |
| SN-7 | The client's engineers can open, build, and extend the source in Visual Studio 2022 |
| SN-8 | The application can be driven non-interactively by a script |


## Deliverable Requirements

### Platform and stack — **[CONFIRMED]**

| Aspect | Decision |
|---|---|
| Target platform | Windows, console application, **x64** |
| Language | **C++17** |
| IDE / toolchain | Visual Studio 2022, stock toolchain, **VS solution only — no CMake** |

### 4.1 End-to-end user workflow — **[CONFIRMED]**

The complete journey, start to finish:

1. The user launches the application from a console. It goes **straight into
   solving — there is no menu**.
2. The application takes the puzzle from **a file, if a path was given as a
   command-line argument; otherwise from stdin**, as 9 lines of 9 characters,
   where `0` or `.` marks an empty cell.
3. The application validates the puzzle. If it is malformed (wrong shape,
   illegal characters) or self-contradictory (a digit repeated in a row, column,
   or box), it **says specifically what is wrong and stops** — it does not
   re-prompt, and it does not hand a broken grid to the solver.
4. The application solves the puzzle. If the solve runs long, it prompts as
   described in §4.4 and the user may stop it.
5. The application prints the result to stdout: the **solved grid,
   pretty-printed with box separators**; or a plain statement that the puzzle
   has no solution; or, where the puzzle has more than one solution, the first
   solution found **plus a note that the solution is not unique**.
6. The application exits with an exit code that reflects the outcome (§4.3).

### 4.2 Input — **[CONFIRMED]**

| Aspect | Decision |
|---|---|
| Sources | Optional file path as the first command-line argument; stdin otherwise |
| Format | 9 lines of 9 characters, digits `1`–`9` for givens |
| Empty cell | `0` or `.` — both accepted, interchangeably |
| Grid size | **9×9 only** for the MVP. Other sizes (4×4, 16×16) are a later tier, so the grid size must not be scattered through the code as a magic number — see D-4 |
| Sample puzzles | A small set ships with the solution: easy, hard (17-clue), unsolvable, malformed, and non-unique — so the application is demonstrable out of the box |

### 4.3 Output and exit codes — **[CONFIRMED]**

| Aspect | Decision |
|---|---|
| Primary output | Pretty-printed 9×9 grid with box separators, to stdout |
| Diagnostics | A specific, human-readable message naming the problem (which cell, which conflict) |
| Streams | **stdout carries the result only** (the solved grid and the non-unique note). Diagnostics and the §4.4 progress prompts go to **stderr**, so a scripted caller capturing stdout is never handed prompt text it has to filter out |
| Later tiers | 81-character single-line output, writing to a file, and solve metrics (elapsed time, guess counts) are **not** in the MVP |
| Exit codes | `0` solved · `1` invalid input (malformed or contradictory) · `2` no solution exists · `3` aborted by the user (§4.4) |

Exit codes are a requirement, not a nicety: ST-4 is confirmed, and a script must
be able to branch on the outcome without parsing text.

### 4.4 Long-running solve: progress prompt and abort — **[CONFIRMED]**

Added by the client on `SN-5`. This is a distinct requirement from the
performance budget, and both hold:

| Aspect | Decision |
|---|---|
| Performance budget | Any standard 9×9 puzzle, including a hard 17-clue grid, solves in **under 10 seconds** on a typical desktop. This is the number the performance requirement is verified against. |
| First progress prompt | If a solve has not finished after **15 seconds**, the application tells the user it is still working and offers to stop. |
| Repeat interval | The prompt **repeats every 10 seconds** thereafter while the solve is still running — 15 s, 25 s, 35 s, and so on. |
| Solve continues during the prompt | **The solve does not pause.** Work continues in the background while the prompt is on screen and while the application is waiting for an answer. Prompting must not cost the user solve time. |
| No answer required | Continuing is the **default**. The prompt is an offer, not a question the program waits on — if the user does not answer, the solve simply carries on to the next prompt. |
| Solve finishes while a prompt is pending | The result is printed and the application exits normally (`0`/`2`). An unanswered prompt is abandoned; the application does **not** wait for a keypress that is no longer relevant. |
| Abort | The user may stop the solve at any prompt. The application then reports that the solve was abandoned at the user's request and exits with code `3`. |
| Prompt destination | Progress prompts and their messages go to **stderr**, so `stdout` carries only the puzzle result. A scripted caller capturing stdout gets a clean grid; a human at a console sees both interleaved as normal. |
| Never silent | The application must never sit with no output while working. Whatever the input, the user always gets either a result, a diagnostic, or a prompt. |
| Non-interactive callers | A scripted caller with no interactive console must not be blocked or delayed by the prompt. Because continuing is the default and the solve never pauses, an unattended run always terminates with a result and an exit code. *How* this is achieved is an engineering decision (§4.4.1). |

The 10-second budget is the expectation for real puzzles; the prompt is the
safety net that guarantees SN-5's "never leave the user waiting on an apparently
hung program" holds even for a pathological input. The **5-second gap** between
the budget (10 s) and the first prompt (15 s) is deliberate: a puzzle that only
just overruns the budget finishes without ever nagging the user.

### 4.4.1 Architecture discovery item — how the prompt and abort are realised

Raised by the client on issue #1: *"we need to determine if that interrupt is
possible in a command prompt application. Will that require multi-threading, or
is there a simpler solution?"*

**This is an engineering question, not a scope one, and it belongs to the
Systems Engineer.** It is recorded here because the client asked it and because
the answer must be written down before implementation starts — it is a required
outcome of architecture discovery, to be documented in `docs/SDD.md`, not left
to whoever writes the code first.

The scope constraints the chosen approach must satisfy — all from the table
above, and non-negotiable:

1. Solving continues while a prompt is displayed and while an answer is awaited.
2. The user can abort at a prompt and the process exits with code `3`.
3. No answer is required; the default is to continue.
4. A completed solve is reported immediately, even with a prompt outstanding.
5. An unattended (piped / redirected / no-console) run never blocks and never
   hangs.
6. Timing is wall-clock against the solve, at 15 s then every 10 s.

Whether that is met with a worker thread, a timer plus a cooperative
check inside the solver loop, non-blocking console polling, a console control
handler, or something else is entirely the Systems Engineer's call. Scope has no
preference and will not express one.

### 4.5 Other confirmed scope decisions

| Decision | Answer |
|---|---|
| Menu / mode selection | None. Single solve action. A menu is a later tier if ever wanted. |
| Multiple solutions | Print the first solution found and state that it is not unique. Counting *all* solutions is a later tier. |
| Solve trace / working shown | Not in the MVP. Final grid only. |
| Algorithm | Not mandated. Any correct method that meets the 1-second budget. **This is the Systems Engineer's decision, not a scope one.** |
| Tests | Automated tests ship as part of the solution and the client can run them (D-6). **Which framework is the Systems Engineer's decision, not the client's.** |

### 4.6 Explicitly out of scope for the MVP

Recorded so each is a decision rather than an omission. Any may be promoted to a
later tier on the client's word:

- Puzzle **generation** (creating new puzzles)
- Puzzle **difficulty rating**
- Hint mode / step-by-step tutoring
- Graphical or web interface of any kind
- Image or OCR input (photographing a newspaper puzzle)
- Non-Windows platforms; cross-platform build files
- Saving / resuming a session, or puzzle history
- Grid sizes other than 9×9
- Solve metrics in the output; machine-readable output format; file output

## 5. Functional scope summary

Grouped to match the RTVM's category blocks so each line converts directly.

| Area | Scope |
|---|---|
| `UI` | Launch straight into solving, no menu; accept an optional file-path argument; read a puzzle from stdin otherwise; the §4.4 progress prompt and abort interaction |
| `DATA-IN` | Parse a 9×9 grid; accept `0` and `.` as empty; validate shape, characters, and internal consistency, naming the specific fault |
| `CORE` | Solve any valid 9×9 puzzle within the 10-second budget; detect unsolvable puzzles; detect non-uniqueness; keep running while a prompt is displayed, and be interruptible so §4.4's abort is possible |
| `DATA-OUT` | Hold the solved grid and the outcome (solved / solved-but-not-unique / invalid / unsolvable / aborted) |
| `OUT` | Pretty-printed grid to stdout; diagnostics and progress prompts to stderr; the four distinct process exit codes |
| `NFR` | 10-second performance budget on a hard 17-clue grid; prompt timing at 15 s then every 10 s; no crash on any input; never silent while working; self-contained x64 Windows executable |

## 6. Deliverable requirements

> **These are non-functional requirements about the artifact handed over, not
> features of the running program.** They are listed separately, and must stay
> separate, because nothing in a test-driven RTVM will surface them on its own —
> there is no behaviour to execute. Per `docs/RTVM.md` they are `DELIV`
> (`RTVM-900`+) items verified by **inspection**.
>
> How each is satisfied is an engineering decision for the Systems Engineer and
> Software Engineer. What follows is *what must be true*, not *how*.

| ID | Deliverable requirement | Source | Status |
|---|---|---|---|
| D-1 | The deliverable includes an **openable Visual Studio 2022 project** — solution and project files committed to the repository — not just source files. | Client, issue #1: "This project should be built using Visual Studio 2022 as an IDE" | **[CONFIRMED]** |
| D-2 | A client engineer can **clone, open, build, and run** the solution in VS 2022 with no undocumented setup steps. | Inferred from D-1; ST-2 | **[CONFIRMED]** |
| D-3 | **No third-party dependencies.** The solution builds with the stock VS 2022 toolchain and the C++ standard library alone, so nothing external can rot or block a build. | ST-3 (must actually ship and run) | **[CONFIRMED]** |
| D-4 | The source is **structured for extension** — the solver logic is separable from the console I/O, so a future UI or a new grid size does not require rewriting the core. | ST-2; §4.2 later-tier grid sizes | **[CONFIRMED]** |
| D-5 | The repository carries a **README** covering how to build, how to run, and the puzzle input format. | ST-2 | **[CONFIRMED]** |
| D-6 | Automated tests are **part of the delivered solution** and runnable by the client. | §4.5 | **[CONFIRMED]** |
| D-7 | Target is **C++17**, **x64**, **Visual Studio solution only** — a cross-platform CMake build is *not* wanted. | Client edit to this document, commit `a773755` | **[CONFIRMED]** |

**Systems Engineer follow-up required:** D-1 through D-7 need to be turned into
build-tooling and documentation decisions and recorded in `docs/SDD.md` build
conventions. They will not appear on their own from the requirement flow — this
section is their only source.

## 7. Acceptance — how we know we are done

The MVP is complete when, on a clean Windows machine with VS 2022:

1. The solution opens and builds without manual intervention (D-1, D-2, D-7).
2. Each shipped sample puzzle (§4.2) produces the correct documented outcome,
   including the non-unique and unsolvable cases.
3. A hard 17-clue puzzle solves within the 10-second budget.
4. Malformed, contradictory, and unsolvable inputs each produce a specific
   message and the correct exit code — no crash, no silence.
5. A solve that exceeds 15 seconds prompts the user, re-prompts every 10 seconds
   after that, and choosing to stop exits cleanly with code `3` (§4.4).
6. A solve that is prompting continues to make progress — an unanswered prompt
   neither pauses the solver nor delays the result once it is found (§4.4).
7. A puzzle piped in from a script produces a result and an exit code without
   waiting on interactive input.
8. `docs/RTVM.md` shows every line item at status `Verified`.

## 8. Change log

| Date | Change |
|---|---|
| 2026-08-04 | Initial draft created from issue #1 and the Systems Engineer's 18-question RFI. Client interview posted to issue #1; all proposals awaiting reply. |
| 2026-08-07 | **Scope refinement from the client (issue #1).** Performance budget changed from **1 s to 10 s**; first progress prompt moved from 5 s to **15 s**; repeat interval changed from 5 s to **10 s**. New requirement: the solve **continues in the background while a prompt is displayed and while awaiting a reply** — prompting must not pause the solver, and continuing is the default so no answer is required. Consequent decisions by the Solutions Architect: a result found while a prompt is outstanding is reported immediately rather than waiting on a keypress; progress prompts and diagnostics go to **stderr** so stdout stays clean for ST-4. The client's question — whether the interrupt is achievable in a console app and whether it needs multi-threading — is an engineering question and is recorded as an architecture-discovery item for the Systems Engineer in §4.4.1, to be answered in `docs/SDD.md`. Also filled in the previously blank Mission Statement, Value, and MVP platform/stack/output fields from already-confirmed scope (no new scope). Exit codes, grid size, input format, and everything in §4.6 are unchanged. |
| 2026-08-04 | **Approved.** Client confirmed all proposed defaults by editing this document (commit `a773755`) and answered D-7 (C++17 / x64 / VS-only). New scope from the client on `SN-5`: a long solve must prompt the user and be abortable — specified in §4.4, with the 5-second threshold, repeat interval, exit code `3`, and the non-interactive-caller constraint set by the Solutions Architect. Restructured §4 into confirmed decisions (input, output, long-solve, other, out-of-scope) rather than open questions. All 18 RFI questions in `docs/RTVM.md` §6 are now answered; §6.5 Q15–Q16 are answered by §6 D-1…D-7, and Q8 (algorithm) and Q17 (test framework) are returned to the Systems Engineer as engineering decisions. |


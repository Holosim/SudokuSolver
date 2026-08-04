# Project Definition — Sudoku Solver

**Owner:** Solutions Architect
**Product:** Sudoku Solver — Windows console application (C++ / Visual Studio 2022)
**Source:** Issue #1 (Project Kickoff)
**Last updated:** 2026-08-04

> ## ⚠️ STATUS: DRAFT — AWAITING CLIENT CONFIRMATION
>
> This document is **not yet approved for handoff**. Everything marked
> **[CONFIRMED]** comes directly from the client. Everything marked
> **[PROPOSED]** is a recommended default I have put to the client on issue
> #1 so they can confirm or overrule it in a single reply — it is *not* a
> decision, and no requirement, test procedure, or code may be written
> against a **[PROPOSED]** item.
>
> When the client replies, the Solutions Architect flips this banner to
> **APPROVED**, marks every item **[CONFIRMED]**, and hands off to the
> Systems Engineer.

---

## 1. Business / mission framing

A Sudoku puzzle is a constraint-satisfaction problem that a person solves
slowly and error-prone by hand. The value of this application is not novelty —
solvers exist — it is that this one is **owned by the client**: it runs on their
platform, in their toolchain, with source they can read and extend.

That framing drives two consequences that matter more than any single feature:

1. **Correctness is the product.** A solver that is fast but occasionally wrong
   is worthless; a solver that is correct and merely adequate in speed is
   valuable. Where the two trade off, correctness wins.
2. **The codebase is part of the deliverable, not a by-product.** See §6.

### Mission statement

> Given a Sudoku puzzle, produce its solution — or a clear, honest statement of
> why it cannot be solved — quickly enough that the user never wonders whether
> the program has hung.

### Value statements

| # | Value | Delivered by |
|---|---|---|
| V1 | The user gets a correct answer without doing the work by hand | Core solver |
| V2 | The user is never left guessing whether the program worked | Explicit success / invalid / unsolvable outcomes |
| V3 | The user can get a puzzle *into* the program without friction | Input method (§4, Q2) |
| V4 | The client's own engineers can extend the program later | Deliverable requirements (§6) |

## 2. Stakeholders

| ID | Stakeholder | Need | Notes |
|---|---|---|---|
| ST-1 | **End user** (puzzle solver) | Enter a puzzle, get the solved grid back, legibly | Assumed non-technical in domain terms but comfortable with a console window |
| ST-2 | **Client engineering team** (maintainer) | Open the solution in VS 2022, understand it, extend it | Drives §6, not §5 |
| ST-3 | **Client sponsor** | A demonstrable, finished, self-contained Windows application | Drives "it must actually ship and run", i.e. no external runtime dependencies |
| ST-4 | *(To confirm)* **Automated/scripted caller** | Invoke non-interactively and branch on the result | Only real if the client confirms Q6 — determines whether exit codes are a requirement |

## 3. Stakeholder needs (SN)

Numbered here because the RTVM traces every requirement back to one of these
(`SN-<n>`, per `docs/RTVM.md` §1).

| ID | Stakeholder need | Status |
|---|---|---|
| SN-1 | The user can supply a Sudoku puzzle to the application | **[CONFIRMED]** — mechanism pending Q2 |
| SN-2 | The application solves any valid, uniquely-solvable standard puzzle | **[CONFIRMED]** — grid sizes pending Q3 |
| SN-3 | The user receives the solved grid in a legible form | **[CONFIRMED]** — format pending Q5 |
| SN-4 | The application tells the user clearly when a puzzle is malformed, contradictory, or unsolvable, rather than failing silently or crashing | **[CONFIRMED]** |
| SN-5 | The application returns a result fast enough to feel immediate | **[PROPOSED]** — budget pending Q4 |
| SN-6 | The application runs on Windows as a console application | **[CONFIRMED]** |
| SN-7 | The client's engineers can open, build, and extend the source in Visual Studio 2022 | **[CONFIRMED]** — see §6 |
| SN-8 | The application can be driven non-interactively by a script | **[PROPOSED]** — pending Q6 |

## 4. MVP definition

### Platform and stack — **[CONFIRMED]** (from the issue)

| Aspect | Decision |
|---|---|
| Target platform | Windows, console application |
| Language | C++ |
| IDE / toolchain | Visual Studio 2022 |

### End-to-end user workflow — **[PROPOSED]**

The minimum shippable slice, start to finish:

1. The user launches the application from a console.
2. The application accepts a puzzle **[PROPOSED: pasted or typed into stdin as
   9 lines of 9 characters, `0` or `.` for an empty cell; and, if a file path is
   given as a command-line argument, read the puzzle from that file instead]**.
3. The application validates the puzzle. If it is malformed or self-contradictory,
   it says so specifically and stops.
4. The application solves the puzzle.
5. The application prints the solved grid to stdout **[PROPOSED: pretty-printed
   with box separators]**, or states plainly that the puzzle has no solution.
6. The application exits.

### Open scope decisions

These are the questions put to the client on issue #1. They consolidate the
Systems Engineer's 18-question RFI in `docs/RTVM.md` §6 into client-facing
decisions. **Each has a recommended default so the client can accept them all
in one reply.**

| Q | Decision | Recommended default | RTVM §6 refs |
|---|---|---|---|
| Q1 | How the app starts | Straight into the core function — no menu. A menu is a later tier if it is ever wanted. | 2 |
| Q2 | How a puzzle gets in | Both: optional file path argument, else read 9 lines from stdin. `0` and `.` both accepted as empty. | 1, 5 |
| Q3 | Grid sizes | 9×9 only for the MVP; the grid size is not hard-coded as a magic number, so 4×4/16×16 remains a later tier rather than a rewrite. | 4 |
| Q4 | Speed | Any standard 9×9 puzzle, including a hard 17-clue grid, solved in **under 1 second** on a typical desktop. | 9 |
| Q5 | How the result comes out | Pretty-printed grid to stdout. Machine-readable 81-character line and file output are later tiers. | 12, 13 |
| Q6 | Scriptability | Distinct exit codes: `0` solved, `1` invalid input, `2` unsolvable. Cheap now, impossible to retrofit politely later. | 14 |
| Q7 | Multiple solutions | Print the first solution found; if the puzzle has more than one, say so alongside it. Full solution counting is a later tier. | 10 |
| Q8 | Bad puzzles | Contradictory-but-well-formed puzzles are rejected up front as invalid input with the conflict named, not silently failed by the solver. Malformed input exits with a message rather than re-prompting. | 6, 7 |
| Q9 | Solve trace / working shown | Not in the MVP. Final grid only. | 11 |
| Q10 | Sample puzzles | Ship a small set of sample puzzle files (easy, hard, unsolvable, malformed) so the app is demonstrable out of the box. | 3 |
| Q11 | Algorithm | No specific algorithm mandated — any correct method meeting Q4. This is an engineering decision, not a scope one. | 8 |
| Q12 | Are tests part of the deliverable | Yes — automated tests ship with the solution and the client can run them. *Which framework* is the Systems Engineer's call, not the client's. | 17 |

### Explicitly out of scope for the MVP

Recorded so it is a decision rather than an omission. Any of these may be
promoted to a later tier on the client's word:

- Puzzle **generation** (creating new puzzles)
- Puzzle **difficulty rating**
- Hint mode / step-by-step tutoring
- Graphical or web interface of any kind
- Image or OCR input (photographing a newspaper puzzle)
- Non-Windows platforms
- Saving / resuming a session, or puzzle history
- Grid sizes other than 9×9

## 5. Functional scope summary

Grouped to match the RTVM's category blocks so each line converts directly.

| Area | Scope |
|---|---|
| `UI` | Launch straight into solving; accept an optional file-path argument; read a puzzle from stdin otherwise |
| `DATA-IN` | Parse a 9×9 grid; accept `0`/`.` as empty; validate shape, characters, and internal consistency |
| `CORE` | Solve any valid 9×9 puzzle within the Q4 budget; detect unsolvable puzzles; detect non-uniqueness |
| `DATA-OUT` | Hold the solved grid and the outcome (solved / invalid / unsolvable / non-unique) |
| `OUT` | Pretty-printed grid to stdout; clear diagnostic messages; distinct process exit codes |
| `NFR` | Q4 performance budget; no crash on any input; self-contained x64 Windows executable |

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
| D-2 | A client engineer can **clone, open, build, and run** the solution in VS 2022 with no undocumented setup steps. | Inferred from D-1; ST-2 | **[PROPOSED]** |
| D-3 | **No third-party dependencies.** The solution builds with the stock VS 2022 toolchain and the C++ standard library alone, so nothing external can rot or block a build. | ST-3 (must actually ship and run) | **[PROPOSED]** |
| D-4 | The source is **structured for extension** — the solver logic is separable from the console I/O, so a future UI or a new grid size does not require rewriting the core. | ST-2; Q3 (later-tier grid sizes) | **[PROPOSED]** |
| D-5 | The repository carries a **README** covering how to build, how to run, and the puzzle input format. | ST-2 | **[PROPOSED]** |
| D-6 | Automated tests are **part of the delivered solution** and runnable by the client. | Q12 | **[PROPOSED]** |
| D-7 | Confirm target: **C++17 or C++20**, **x64**. VS-only build, or is a cross-platform CMake build also wanted? | Systems Engineer RFI Q15 | **❓ OPEN — needs client answer** |

**Systems Engineer follow-up required:** D-1 through D-6 need to be turned into
build-tooling and documentation decisions and recorded in `docs/SDD.md` build
conventions. They will not appear on their own from the requirement flow — this
section is their only source.

## 7. Acceptance — how we know we are done

The MVP is complete when, on a clean Windows machine with VS 2022:

1. The solution opens and builds without manual intervention (D-1, D-2).
2. Each shipped sample puzzle (Q10) produces the correct documented outcome.
3. A hard 17-clue puzzle solves within the Q4 budget.
4. Malformed, contradictory, and unsolvable inputs each produce a specific
   message and the correct exit code — no crash, no silence.
5. `docs/RTVM.md` shows every line item at status `Verified`.

## 8. Change log

| Date | Change |
|---|---|
| 2026-08-04 | Initial draft created from issue #1 and the Systems Engineer's 18-question RFI. Client interview posted to issue #1; all **[PROPOSED]** items awaiting reply. |

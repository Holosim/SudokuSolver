---
name: requirements-traps
description: Requirements-writing traps hit on SudokuSolver — untestable thresholds, self-defeating performance requirements, and fixtures with overlapping faults
metadata:
  type: feedback
---

# Requirements traps worth not re-learning

## A performance budget can make its own safety-net requirement untestable

SudokuSolver requires both "hard 17-clue solves in under 10 s" and
"a solve still running at 15 s prompts the user". Any solver good enough
for the first will never reach the second on real input — including the
famous brute-force-hostile grids, which an MRV-ordered solver dispatches
in milliseconds. There is no puzzle that exercises the prompt path.

**Why:** the two requirements were written independently and each is
fine alone; the conflict only appears when you try to write the test.

**How to apply:** whenever a requirement is phrased "if X takes longer
than T", check whether another requirement guarantees X never takes T.
If so, the requirement needs a **build-provided diagnostic hook** as its
own RTVM line item (here `RTVM-507`), documented in the SDD and not the
README, and inert in normal use. Write the hook as a requirement, not as
a note in a test procedure — otherwise nobody builds it and the Test
Engineer is blocked at the worst moment.

## "Still making progress" has to be made observable or it is not a test

An acceptance criterion of "the solve continues while a prompt is up"
is unverifiable from the outside. It needed a companion requirement
(`RTVM-204`) for a monotonic search-step counter readable while the
solve is in flight, and the timing test then asserts the counter strictly
increases across each prompt window.

**How to apply:** for any requirement about something *continuing*,
*not stalling*, or *not blocking*, add the observable that makes it
checkable as its own line item in the same pass.

## Hand-picked invalid fixtures usually carry more than one fault

The first row-duplicate fixture I wrote also happened to create a column
duplicate, which would have made the expected diagnostic depend on the
implementation's check order — an unfalsifiable test.

**Why:** Sudoku givens interact; a single character edit propagates into
three units at once.

**How to apply:** machine-verify every negative fixture for *exactly one*
fault of *exactly the named kind* before writing it into a test
procedure. Same discipline applies to any structured-input format with
overlapping validation rules, not just Sudoku. Generating candidates by
brute force and filtering to single-fault results takes about a minute.

## Timing thresholds need a tolerance and a reference machine

"15 seconds" is not testable on a general-purpose OS. Every threshold got
an explicit ±1.0 s, and the performance budget got a pinned reference
machine spec in the RTVM rather than "a typical desktop".

## Ambiguous stream assignment hides in cross-section tension

Two sections of the same approved scope document disagreed about whether
the "no solution" statement is a *result* (stdout) or a *diagnostic*
(stderr). Neither was wrong; they were written at different times.

**How to apply:** when scope has a "stdout is clean for scripts"
requirement, enumerate every message the program can emit and assign each
a stream explicitly in the RTVM, then add an aggregate test asserting
stdout contains none of the diagnostic substrings. The per-message rules
drift; the aggregate assertion does not.

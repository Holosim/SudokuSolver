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

## Two of my own requirements can contradict each other, and only the SDD pass finds it

RTVM-504 said "never silent — no interval longer than the repeat interval
(11.0 s) with no output". RTVM-501 said "first prompt at 15 s". Both were
Approved. Together they made TP-504 unpassable by *any* conforming
implementation: the 0–15 s window is silent by design. Nobody noticed until I
tried to design the thing that had to satisfy both.

**Why:** each requirement was written from a different sentence of the same
scope section, and each is individually correct. A safety-net requirement
("never silent", "always responds", "no gap longer than T") is written as a
universal, but a threshold requirement elsewhere carves an intentional
exception out of it. The universal never mentions the exception.

**How to apply:** when the RTVM contains a *universal* bound ("no interval
longer than…", "always within…", "never more than…"), enumerate every other
requirement that deliberately delays or suppresses the thing being bounded, and
write the universal as a **piecewise** bound naming those exceptions. Do this
during the RTVM pass; the SDD pass is the last cheap chance to catch it, and
after that it lands on the Test Engineer mid-procedure. Fixing it as an §7
interpretation (I-12 here) is enough — it changes the assertion, not the
behaviour, so it is not a scope change and does not need escalating.

## Ambiguous stream assignment hides in cross-section tension

Two sections of the same approved scope document disagreed about whether
the "no solution" statement is a *result* (stdout) or a *diagnostic*
(stderr). Neither was wrong; they were written at different times.

**How to apply:** when scope has a "stdout is clean for scripts"
requirement, enumerate every message the program can emit and assign each
a stream explicitly in the RTVM, then add an aggregate test asserting
stdout contains none of the diagnostic substrings. The per-message rules
drift; the aggregate assertion does not.

## The verification environment can fail to intersect the target platform (2026-08-07)

SudokuSolver is a Windows/VS 2022 deliverable; every agent run executes on an
Ubuntu runner with no MSVC, no `msbuild`, no Visual Studio and no console
handles. So most of the RTVM — every console test, every timing test, every
MSVC build inspection — is unexecutable *by the pipeline that is supposed to
verify it*, and that only became visible at the first build (issue #5).

**Why:** nothing in the requirements pass asks "what machine executes this
procedure?" Each TP is written against the target platform, which is correct,
and the gap lives entirely outside the document.

**How to apply:** when the target platform and the CI platform differ, say so
in the RTVM as its own section during the RTVM pass, and split each affected
procedure into clauses that the pipeline can execute and clauses it cannot.
Then never let a partially-executed procedure be recorded as if it were fully
executed — a clause-level ledger (`docs/RTVM.md` §9.2 here) is what stops
"passed" from quietly meaning "passed the half we could run". The *where does
this get executed* question is a process decision, not a requirements one:
escalate it to the Solutions Architect as its own `type:blocker` issue rather
than deciding it (issue #23 here).

## Repository housekeeping files can fail a requirement silently

A template `.gitignore` excluding `*.sln` would have failed RTVM-900 ("a
committed, openable solution, not source files alone") with no visible symptom
— the tree looks complete and only the client's clone is broken. A blanket
`* text=auto` in `.gitattributes` would have checked LF fixtures out as CRLF on
Windows and failed a byte-for-byte fixture diff on the client's machine and
nowhere else.

**Why:** these files are treated as housekeeping by everyone, so no requirement
points at them and no inspection greps them.

**How to apply:** if a requirement says an artifact is *committed*, or a test
procedure compares bytes, name `.gitignore`/`.gitattributes` explicitly in the
SDD build-conventions section. Both were caught by the Software Engineer at
scaffold time here; that was luck, not process.

## A classification rule inside one requirement can silently outrank a global precedence requirement (2026-08-13)

RTVM-106 said "interior whitespace is an illegal character". RTVM-105 fixed a
global precedence: shape → character → contradiction. Together they made
TP-106's own negative fixture (`098 000060`, 10 characters) assert the *wrong*
fault: strict precedence makes it a length fault, because the extra space is
what breaks the length. The clause "interior whitespace is an illegal
character" was then nearly unreachable — a line carrying an extra space is by
construction not 9 characters. Both the Software Engineer and the Test Engineer
found it, and both correctly declined to rule; I ruled it as §7 I-15
(whitespace outranks *its own line's* length check, nothing wider).

**Why:** a *classification* rule ("X counts as fault kind K") and an *ordering*
rule ("kind K1 is reported before K2") are written in different requirements
and read as independent, but classification decides which bucket the ordering
then sorts — so one silently determines the other's outcome.

**How to apply:** whenever a requirement declares that something "is a <fault
kind>", check it against the precedence requirement immediately, and check the
literal test fixture: if the input that triggers the classification *also*
triggers a higher-precedence kind by construction, the clause is dead letter
and the fixture is contradictory. Rule with the diagnostic that locates the
fault for the user ("illegal character ' ' at r3c4" beats "line 3 has 10
characters"), and state the exception's scope in one sentence — mine is "only
whitespace, only against the same line's length" — or it will be read as
loosening the whole precedence order. Also: when an implementer has already
shipped and tested one reading, ratify *that* reading unless it is wrong; the
alternative costs a rebuild and a retest for nothing.

## An interface section can name a type it never defines

`docs/SDD.md` §2.6 used `ParseResult` as a function's return type and never
specified it — reviewed by three roles without anyone noticing, because the
name reads as self-explanatory.

**How to apply:** when writing an interface block, check every type appearing
in a signature has a definition somewhere in the document. The types that get
skipped are the ones whose names sound obvious (`*Result`, `*Report`,
`*Options`). Where the answer is a sum type, mirror whichever type in the same
document already makes "neither case" unrepresentable — consistency is worth
more than the marginal design.

## An SDD can state the same invariant twice, in two places, incompatibly (2026-08-13)

`docs/SDD.md` §2.3 said the 0-based → 1-based cell conversion "happens in
exactly one place, in `Messages`"; §2.5 declared `CellRef` **1-based**. Both
were written in the same SDD pass and neither is wrong alone — but if the fault
object already carries 1-based cells, `Messages` cannot be where the `+1`
happens. It surfaced only when the Software Engineer had to pick one (issue
#7), and the Test Engineer then flagged that a test hung off the answer.

**Why:** a "single point of truth" clause names a *place*; a type declaration
names a *state*. They're written in different sections, for different readers,
and they only contradict once someone traces a value from producer to renderer.

**How to apply:** when the SDD says "X happens in exactly one place, in Y",
check every type declaration on X's path — if any of them claims to already be
in the post-X state, the clause is wrong about Y. Resolve toward **where the
data is constructed**, not where it is rendered: the constructor is the
narrower funnel, and it keeps the rendering layer free of arithmetic. Then make
"exactly one place" literally true by naming a single function
(`cellRefFromZeroBased()` here) rather than a module. Ruled as §7 I-16 — an
interpretation, not a scope change, because the delivered code and the test
procedure already agreed with each other.

## A compile-time invariant needs mutation evidence or it is unverified (2026-08-13)

RTVM-300's "exactly one outcome, never none, never two" was implemented as
`static_assert`s plus `default`-less switches. A green build proves nothing
about them — a deleted or vacuous `static_assert` compiles just as happily as a
correct one.

**How to apply:** whenever a requirement is satisfied by a compile-time
construct (`static_assert`, deleted ctor, exhaustive switch, structured binding
over every field), the test procedure's evidence is a **mutation table**: the
mutation applied and the observed build/test failure. Both engineers produced
one unprompted here; write it into the §9 ledger so it is the standing
expectation rather than a habit. One recorded non-defect worth keeping:
`!std::is_default_constructible_v<T>` is evaluated from outside the class, so
adding a *private* default ctor does not trip it — only a public one.

## A correctness fixture can pass without exercising the algorithm it verifies (2026-08-13)

Both TP-200 fixtures (`P-EASY`, `P-HARD17`) fell to constraint propagation
alone — `nodesExplored == 1`. The procedure passed honestly and verified the
requirement, but the MRV branch/backtrack half of the design never executed.
Mutation confirmed it: descending candidate order, and hidden singles removed
entirely, both still passed. The Test Engineer found this and correctly
reported it as coverage, not as a failure.

**Why:** a requirement about the *answer* ("produces the unique solution") says
nothing about the *route*, so fixtures chosen for being canonical or difficult
can systematically miss the branch the design's margin depends on. The famous
hard fixture is the worst offender — 17-clue puzzles are hard for *humans*, not
for a propagator.

**How to apply:** when a requirement is verified by output equality but the SDD
specifies an algorithm with a distinguishable slow path, add a fixture chosen
for *path coverage* and an assertion on the observable that proves the path ran
(here `nodesExplored() > 1`). Assert the **inequality, not the count** — the
count is an implementation property and pinning it fails on any legitimate
optimisation. Cheapest construction: dig the new fixture out of a solution
fixture that already exists, so its expected output is an already-verified
value and the fixture adds no new expected data to get wrong. Machine-verify
three properties (unique solution; solution equals the existing fixture;
propagation alone gets stuck) *and* run it against the delivered binary before
writing the clause, so you never specify a clause the shipped code fails.

**Do not cancel the passing test iteration for this.** The cancel rule is for
an ambiguity whose resolution needs a code change; a coverage clause that needs
only a test fixture is additive. Record it as an outstanding clause with a
re-run trigger naming the next issue that already opens the same test file
(#11 here), and say in the ledger that the code is not suspected.

## The format decision the normative block doesn't state (2026-08-13, #9)

A byte-normative output block pinned as an ASCII picture in the RTVM (`§6.2`'s
13-line grid) silently omits **whether the last line is terminated**. Nobody
notices at the requirement it belongs to — TP-400 normalises line endings and
counts lines, so either choice passes — and it surfaces one issue later, at the
requirement that appends something *after* the block (RTVM-401's non-uniqueness
note, which lands on its own line only if the grid terminated its last one).

**Why:** a picture in a fenced code block communicates glyphs and alignment
perfectly and terminators not at all. The Software Engineer has to choose, and
did choose correctly here, but it was an unrecorded choice until they flagged it.

**How to apply:** when pinning any byte-normative block, state the terminator
count explicitly, and say which spelling is normalised away (CRLF vs LF) versus
which property is normative (the count). Then find the *later* requirement that
concatenates onto it and make sure the two agree. Same class of omission to look
for: trailing whitespace, whether an empty/unset field has a glyph at all
(§6.2's empty-cell rendering is deliberately unspecified because no requirement
prints an unsolved grid — a surviving mutant proved that gap exists, and it is
documented rather than latent).

## An instrumentation clause can be unfalsifiable on the very fixture it names, for a reason invisible from the RTVM text (2026-08-14, #12)

TP-202's instrumentation clause ("assert the solver stopped after finding the
second solution") was written in the same sentence as `P-NONUNIQUE`'s
outcome/grid checks, so it reads as if it runs against that fixture too. It
can't: `P-NONUNIQUE` has exactly one branch cell with exactly two candidates,
so its search tree is exhausted at 3 nodes whether `maxSolutions` is 2 or
1,000,000 — a node-count comparison there can't tell "the cap stopped it" from
"there was nothing left to find regardless". `P-BLANK` (already named in the
project for a different reason — huge branching factor, `SolvedNotUnique` at
exit 0) does show the cap doing real work: raising it by one measurably grows
the search. Both the Software Engineer and the Test Engineer independently
measured the same node counts before I ruled on it (§7 I-20).

**Why:** a "does X and not Y" instrumentation clause needs a fixture where Y
is actually reachable if the code were wrong; a fixture chosen for its
*outcome* properties (exactly two known solutions, so the printed grid is
checkable) is not automatically a fixture with search left over once the cap
is hit. The two needs — checkable answer, checkable search-bound — pull
toward different fixtures, and nothing about the RTVM prose surfaces that
they're different needs until someone tries to make the assertion fail.

**How to apply:** when an instrumentation/bound clause is written against the
same fixture as an answer-correctness clause in the same sentence, ask
separately "does this fixture have anything left to explore past the bound
being tested?" before trusting the pairing. If a fixture already exists in
the project for a different property (large branching factor, long-running,
adversarial) it is usually the right one for the bound clause — reuse it
rather than inventing a third fixture. Rule the fixture swap as a §7
interpretation citing the measured evidence from both roles; it's a procedure
correction, not a scope change, and costs nothing once the numbers are in.

## A forward-pointing claim in an earlier §9 section can be wrong, and the fix is to correct it in place, not delete it (2026-08-14, #12)

§9.7 (issue #8) said "TP-202 (#12) is the only place [ascending candidate
order] becomes provable." It was wrong: TP-202's own wording forbids pinning
`P-NONUNIQUE`'s result to a specific one of its two solutions ("must not
assert which, since that depends on search order") — precisely the assertion
that would be needed to prove *which* order the solver tried first. A test
written to survive a future implementation change to the search cannot also
assert which branch that search takes. #12 delivered exactly that: outcome
accepted as either fixture, by design.

**Why:** an earlier issue's own re-run trigger is a prediction about what a
later issue's test will be able to show, made before that test is written. It
reads as settled because it's in the ledger, but it's still a forecast, and
this project's own scoping (RTVM-202 disallows pinning the answer) can defeat
it without anyone having done anything wrong at either end.

**How to apply:** when a fast-path update lands evidence that contradicts an
earlier section's forward-pointing claim, correct that section in place
(strikethrough the wrong sentence, explain why, leave the original text
visible) rather than silently rewriting it or leaving it uncorrected for the
next reader to trust. State plainly what stays permanently unevidenced as a
result, and why that's a deliberate consequence of another ruling (here: TP-202
robustness) rather than a gap someone still owes.

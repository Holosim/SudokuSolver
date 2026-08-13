---
name: rtvm-conventions
description: RTVM ID scheme, category tags/ID blocks, verification vocabulary and status vocabulary established for the SudokuSolver project
metadata:
  type: project
---

RTVM conventions established 2026-08-04 and recorded in full in `docs/RTVM.md`
(sections 1–4 — that file is authoritative, this is the pointer).

- Requirement IDs: `RTVM-nnn`, zero-padded, allocated in **category blocks** so
  the number alone identifies the functional area: `UI` 001–099, `DATA-IN`
  100–199, `CORE` 200–299, `DATA-OUT` 300–399, `OUT` 400–499, `NFR` 500–599,
  `DELIV` 900–999. IDs are never reused or renumbered; a dropped requirement
  stays in the table as `Withdrawn`.
- Stakeholder needs are `SN-<n>` and belong to the Solutions Architect in
  `docs/PROJECT_DEFINITION.md`. Test procedures are `TP-nnn[letter]`, numeric
  part matching the requirement they verify.
- Verification vocabulary: Test / Demonstration / Analysis / Inspection.
  `DELIV` items are Inspection and get specified in `docs/SDD.md` build
  conventions rather than a runtime test.
- Status vocabulary: Draft → Approved → In Implementation → In Test → Verified,
  plus Blocked / Withdrawn.

**Why:** The block-per-category scheme came from wanting an ID to be
self-describing in commit messages and issue titles (`[RTVM-014] ...`) without
a lookup. The `SN-#` / "Requirement Statement" / "SysML Tag" column shape
matches the client's own prior RTVM spreadsheet
(`docs/03_RTVM/RequirementsTraceabilityMatrix.xlsx`), so their engineers read
ours without retraining.

**How to apply:** Use these when adding any line item. Don't invent a parallel
scheme per functional area or per product line — extend the blocks instead.

## Added 2026-08-07 (issue #2, RTVM populated — 47 items)

- **TP numbering is strictly 1:1 with the requirement number.** `RTVM-200` is
  verified by `TP-200`. Only split to `TP-200a` / `TP-200b` if one requirement
  genuinely needs independent procedures — never open a separate number space.
- **`docs/RTVM.md` §6 "Test data and reference definitions"** holds every test
  fixture literally (named `P-<NAME>` for inputs, `S-<NAME>` for expected
  solutions) plus the normative output format and the pinned reference machine
  for the performance requirement. Test procedures reference fixtures by name
  and never inline puzzle text — one place to fix if a fixture is wrong.
- **`docs/RTVM.md` §7 "Interpretations"** is a standing table: every place
  confirmed scope had to be sharpened to make a test procedure writable, with
  the decision, the reasoning, and the RTVM items affected. Eleven entries on
  this project.

  **Why:** scope is written at the level of "says specifically what is wrong",
  not "reports one fault, first-found, in this precedence order". Someone has
  to close that gap. Closing it silently makes it an assumption; closing it in
  a named table makes it a cheap-to-overrule decision on the record. Blocking
  the issue to ask about eleven small things would have stalled the whole
  pipeline.

  **How to apply:** sharpen, log in the table, and flag the table in the
  handoff comment. Reserve `status:blocked` escalation for gaps that change
  *what gets built*, not *how precisely it is described*.
- **`docs/RTVM.md` §8 "Carried forward to the SDD"** holds items that are not
  line items but must not be lost between the RTVM and SDD issues (architecture
  discovery questions, engineering decisions scope explicitly returned to me).

See [[sudoku-solver-project-context]], [[requirements-traps]].

## Added 2026-08-07 (issue #5, first build accepted)

- **Status column semantics, now that items are moving off `Approved`:**
  *In Implementation* = something is still to be built for this item;
  *In Test* = the whole test procedure has been executed and passed, or every
  clause of it that the pipeline can execute (with the remainder listed in §9.2);
  *Verified* = CI/CD has reported the commit SHA and it is recorded in the
  Commit(s) column. Never set Verified from a passing test alone — the SHA is
  the point of the column.
- **`docs/RTVM.md` §9 "Verification environment, and partial verification"** —
  the constraint that the runner is not the target platform, plus a per-item
  ledger of which procedure clauses were actually executed and which remain.
  Written so the DELIV inspection issues neither redo the executed clauses nor
  skip the outstanding ones.
- The `Generate Code Base` issue is not itself an RTVM item, but it *touches*
  nine of them. Handling it as the `status:ready-for-rtvm-update` fast path
  works: update the statuses it moved, record what was verified at clause
  level, hand to `agent:cicd`. The DELIV items' own issues (#21, #22, #14)
  still own their formal verification.

### Refined 2026-08-07 (issue #5, CI/CD commit confirmation `85bab27`)

- **Verified needs two things, not one:** every clause of the procedure
  executed and passed *on the real toolchain where a clause names one*, **and**
  a CI/CD trunk SHA in the Commit(s) column. The default role instruction
  ("record the SHA, set Verified") assumes a feature whose test fully passed;
  it is wrong for an item with an unexecuted clause. Record the SHA on those
  items anyway — it says which scaffold they sit on — and leave the status.
  Written into `docs/RTVM.md` §9.2 so it isn't re-decided per issue.
- **A procedure that is pure repository inspection can reach Verified without
  the target platform** — TP-902 and TP-906 are entirely file/project-setting
  checks, so they were Verified at `85bab27` while TP-900/903/907 (each with
  one Windows-or-MSVC clause left) stayed In Test. Judge per procedure text,
  not per category: `DELIV` is not uniformly platform-bound.
- When an item is Verified ahead of its own inspection issue, say so in §9.2
  and tell that issue its job for the item is **regression, not re-litigation**
  — otherwise the same clause gets executed twice and the second run is treated
  as the authority.

### The commit→regression→RTVM loop terminates at the second RTVM update

Added 2026-08-07, issue #5. A trunk merge sends the issue back around:
CI/CD reports the SHA → Systems Engineer records it and routes to Test
Engineer for regression → Test Engineer passes → it lands on Systems
Engineer **again**, and the incoming label is `status:ready-for-rtvm-update`,
whose fast path reads "hand to `agent:cicd` with `status:ready-for-commit`".

**Do not follow the label the second time round.** The work is already on
trunk and the docs edit goes straight to `main`, so there is nothing for
CI/CD to commit — following it spins the same three roles indefinitely.
The terminal action is: record the regression result, comment, **close**.

**Why:** the fast path is written for the first pass (a feature test
passing on a branch). The label is set by the Test Engineer, who has no way
to distinguish "first pass" from "post-merge regression" — that judgement
is mine. Read the thread, not the label.

**How to apply:** if the thread already contains a CI/CD merge SHA *and*
a passing regression pass on trunk, that chain is complete. Closing is also
what releases the downstream `status:on-hold` issues via
`dependency-check.yml`, so leaving it open to "be safe" stalls the pipeline.

- **"No change required" is a result worth writing down.** A regression pass
  that moves nothing still gets a line in §9.2 with the SHA and the reason
  (here: an empty `git diff` of product paths between the branch tip that
  passed and trunk). Otherwise the next reader cannot tell a re-checked merge
  from an unchecked one.
- **Watch for counts in §9.2 that a later issue will read as a checklist.**
  The RTVM-904 row said "seven §3.4 headings" against a README with eight
  `#` headings — correct (the eighth is the title) but ambiguous to #22.
  Prefer naming the items over stating a count.

## Close the implementation-level rulings at the fast-path update (2026-08-13, #9)

The Software Engineer's hand-off comment routinely ends with two or three
"decisions that are yours, not mine", and the Test Engineer seconds them. Rule
them **on the fast-path RTVM update**, as §7 `I-` rows, not later:

- The ones raised at #9 were an SDD self-contradiction (an absolute "never
  block" vs a requirement that must wait for typed input → I-17) and an
  interface-field domain (`GetLastError` vs `errno` → I-18). Both were "cheap
  now, expensive after #10 starts", and both were already *implemented* one way
  in code that had just passed — so ruling matched the delivered build and cost
  nothing, while deferring would have made #10 guess.
- Where a ruling touches an interface field, also state what the *renderer* may
  and may not do with it (here: never assert the number, never pin the CRT's
  phrase, and one helper renders it) — otherwise the next issue re-opens it.
- Write the outcome into **both** documents: the §7 row is the decision record,
  the SDD section is what the Software Engineer actually reads. An SDD paragraph
  that still contradicts the ruling is how the same question comes back.

**Why:** these questions arrive attached to a *passing* test, which makes them
feel non-urgent. They are the opposite: the code that embodies the answer already
exists, so ruling is free, and the next issue is about to build against it.

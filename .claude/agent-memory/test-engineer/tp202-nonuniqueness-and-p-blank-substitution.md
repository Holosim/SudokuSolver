---
name: tp202-nonuniqueness-and-p-blank-substitution
description: Issue #12 (RTVM-202/RTVM-401) verification — independently reproduced the P-NONUNIQUE node-count claim and confirmed TP-401's wording byte-for-byte; what to check next time this area changes.
metadata:
  type: project
---

Verified on issue #12 (2026-08-14), building on [[solver-coverage-limits]].

**The Software Engineer's TP-202 instrumentation substitution (P-BLANK instead
of P-NONUNIQUE) is correct — independently reproduced, not just re-read.** A
standalone `/tmp` probe (links `solve()` directly, no test framework) gave:

- `P-NONUNIQUE`: `nodesExplored()` == 3 at `maxSolutions=2` **and**
  `maxSolutions=1'000'000`. The tree is genuinely exhausted either way, so a
  node-count comparison on this fixture cannot show the cap doing anything —
  matches the reasoning documented in `SolverTests.cpp` exactly.
- `P-BLANK`: 49 nodes at `maxSolutions=2`, 51 at `maxSolutions=3`. Strictly
  grows with the cap, which is what actually falsifies "the cap does nothing".

**How to apply:** don't just trust a solver-instrumentation claim like this
from a hand-off comment — it's cheap to re-derive with a five-line `/tmp`
probe against the real `solve()`, and it converts "the SE says so" into a
measured fact. The open question (should TP-202's wording in `docs/RTVM.md`
name `P-BLANK` for this clause) is a spec ruling for the Systems Engineer, not
a test failure — the substitution is evidenced, so it passes as-is.

**TP-401 checked byte-for-byte, not just "note text present".** Built the
expected file by extracting the §6.2 fenced block **and** the TP-401
reference-wording line programmatically from `docs/RTVM.md` (regex, not
transcription) and `cmp`'d against the real console binary's stdout on
`samples/nonunique.txt`. `cmp` reported byte-identical, including the
newline after the note line. Also confirmed the control case at the console
level, not just the unit level: `samples/easy.txt` stdout is exactly 338
bytes (13×26, the plain grid) with no note line appended, i.e. `Solved` never
leaks `SolvedNotUnique` wording.

Both RTVM-202 and RTVM-401 were still "Approved" (not "In Test") in the
matrix at test time — expected, since the Systems Engineer updates that
column after this pass, per the standard two-step handoff.

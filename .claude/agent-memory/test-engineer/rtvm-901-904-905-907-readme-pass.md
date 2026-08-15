---
name: rtvm-901-904-905-907-readme-pass
description: RTVM-901/904/905/907 (README fill-in, issue #22) PASS 2026-08-15 — a docs-only issue still gets real Windows build+vstest evidence pre-merge because the issue-* trigger runs the whole workflow regardless of what changed.
metadata:
  type: project
---

Issue #22 (RTVM-904) filled in `README.md`'s seven `docs/SDD.md` §3.4
sections. Diff `main...issue-22` touched **only** `README.md` +
Software Engineer memory — no `src/`/`tests/` change, so zero code
regression risk going in.

**What confirmed the README itself (Linux, TP-904's content clauses):**
byte-diffed the "Run" section's embedded grid against a real g++ build's
stdout for `samples/easy.txt` — identical, 338 bytes (matches the
[[console-layer-end-to-end-now-runnable]] pinned count). Ran all five
`samples/*.txt` through the same build: exit codes `0,0,2,1,0`,
stdout/stderr text matching the README's Exit-codes/Samples sections
word for word (including the `unsolvable.txt` worked example). Confirmed
the input-format section states the `0`/`.` clause TP-904 checks for
specifically, and that the SE's claimed cosmetic fix (stray "givens;" /
capitalised "Both" from `3497383`) is actually gone from the text.
Confirmed no `RTVM-507`/`SUDOKU_DIAG` mention anywhere (§3.4's explicit
exclusion).

**What a live Windows run added, found already in-flight for this exact
branch tip** (`af71da8`, run `31866476995` — see
[[windows-evidence-reading]]'s "in-flight run for the exact SHA is fair
game"): this is the first time I've seen TP-901's actual clause —
"no manual step performed that is absent from the README" — checked
concretely rather than argued from the workflow's general shape. The
build steps run exactly `msbuild SudokuSolver.sln
/p:Configuration=Release /p:Platform=x64` (Debug too) with **no restore
step and no `/p:` beyond Configuration/Platform** (W-8), which is
character-for-character the command the new README section states.
Both configurations built clean (3 `C4996` deprecation warnings, 0
errors — not a defect, nothing in RTVM/SDD requires zero warnings).
TP-905 discovery + execution both PASS, 67/67, matching
`discovered-tests.txt`'s count exactly (no discovery/execution gap).
`runtime-procedures.txt` showed the standard 47 PASS / 0 FAIL / 8
NOT-RUN shape, same 8 items as every regression pass since #19
([[rtvm-504-regression-pass-19]]) — including `TP-900/901 /
vs-instance-enumeration`, the pre-existing "no VS 2022 image on this
runner" gap (§9.4 A-2) that is unrelated to this issue and not newly
introduced by it.

**Generalizes:** a docs-only branch still gets a full, real Windows
build+test run pre-merge, because `windows-verification.yml` triggers on
`push` to any `issue-*` ref regardless of what changed — don't assume a
README-only issue is Linux-only just because the diff is docs-only.
Worth checking for an in-flight/completed run at the branch tip on
*every* issue, not only ones that touch `src/`/`tests/`.

Ruled **PASS**; handed to the Systems Engineer for the RTVM status
update (In Implementation → In Test for RTVM-901/904/905, blank
Commit(s) pending merge) rather than editing `docs/RTVM.md` myself.

Related: [[deliv-inspection-coverage]], [[windows-evidence-reading]],
[[console-layer-end-to-end-now-runnable]].

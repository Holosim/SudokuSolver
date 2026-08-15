---
name: trunk-regression-scope
description: How to scope a post-merge regression pass on this repo — diff product content against the already-passed branch tip first, then re-run only what that diff can have affected.
metadata:
  type: feedback
---

For a CI/CD-requested regression pass on trunk, **first** diff product content
between the branch tip that already passed and the trunk tip, over
`src tests samples *.sln .gitignore .gitattributes README.md`. If it is empty,
the merge changed no product content and the pass is a re-confirmation, not new
ground — say so in the comment and re-run the procedures anyway, but frame the
result that way.

**The runner's clone is shallow (depth 1), so `git diff <old-sha> <trunk>`
cannot work** — the old objects are not present and `git log` shows one commit.
Use the API instead, which needs no fetch:
`gh api repos/Holosim/SudokuSolver/compare/<passed-sha>...main --jq '{ahead:.ahead_by,files:[.files[].filename]}'`.
Confirmed on issue #6's regression pass, 2026-08-13.

**Why:** established on issue #5 (2026-08-07). Both CI/CD and the Systems
Engineer independently stated the scope as "re-run what you already ran, not
new ground", and the empty diff is what makes that claim checkable rather than
assumed. It also catches the opposite case cheaply: a merge that *did* silently
alter product content shows up immediately instead of being missed because the
conflict was "only in docs".

**How to apply:** on any `status:ready-for-*` regression request after a merge.
Two things deserve re-running regardless of the diff, because they fail
*silently* and only on the client's machine:

- `samples/*.txt` byte diff against the `docs/RTVM.md` §6.1 fixtures, plus the
  `.gitattributes` LF pin (TP-907).
- `git check-ignore` on `*.sln` / `*.vcxproj` — an ignored solution leaves the
  tree looking complete and only the clone broken (RTVM-900).

**After a merge whose conflict was in `docs/RTVM.md` or `docs/SDD.md`, inspect
the matrix as part of the regression, not just the code.** Confirm the
**Commit(s)** column of *previously merged* requirements still holds its old
trunk SHA, and that the §9.x coverage sections are present and un-truncated. A
"take my branch's version" merge note expires the moment anything else merges,
and taking a doc wholesale silently deletes the trunk SHAs the matrix exists to
record — near-miss on #7's merge (2026-08-13), caught by CI/CD resolving hunk by
hunk. The requirements whose rows the conflict touched are in regression scope
even when they belong to a different issue: #7's merge put TP-100/101/106 back
in scope because #6's SHA rows were in the conflicted hunks.

**Re-run the compare yourself even when the hand-off states the scope.** On
#8's regression (2026-08-13) the Systems Engineer's comment named three changed
files; by the time I ran it the answer was five, because their *own* RTVM
commit landed after they wrote the comment. Same again on #9's (twelve files
stated, fifteen measured, 19 commits ahead) — and the Systems Engineer now
writes "re-derive this on receipt" into the §9.x section itself, so it is an
expectation, not just prudence. A stated scope is a snapshot of the trunk at
writing time, not of the trunk you test. The same staleness applies to any
*run id* a hand-off names; see [[windows-evidence-reading]].

**A regression pass can carry deferred clauses that are new ground.** §9.x
sections sometimes park a clause deliberately — #9's §9.8.2 held TP-101 and
TP-106's end-to-end halves back because their re-run trigger is worded against
*trunk*, and advance evidence taken on a branch does not satisfy that wording.
Read the §9.x section for the merged issue before assuming "re-run what you
already ran": part of the ask may be a first execution, and it is the part that
makes the pass non-trivial. Distinguish it in the comment from the
re-confirmation half.

**Watch out for a `.vcxproj` `Include=` that is a macro or glob, not a path.**
`$(SolutionDir)samples\*.txt` (the `CopySamples` step) does not resolve on disk
and a naive existence check flags it as missing — which is why earlier passes
reported 38/38 and 76/76 while a fresh script says 78/79. Skip entries
containing `$(` or `*`, and say so, rather than reporting a phantom defect.

**Two things the Systems Engineer has now twice asked be left out of a
regression pass, and I should not volunteer:** mutation evidence over code that
has not changed (§9.6's rule — it re-tests the feature, not the merge), and
**new test clauses added to a procedure by the RTVM update itself**, which
belong to the issue that owns the fixture. Running one in passing does not
credit the requirement anyway.

Also: do **not** re-derive a verdict on items already marked Verified. The
Systems Engineer asked explicitly that Verified items only be checked for
regression, not re-litigated. See [[deliv-inspection-coverage]] and
[[no-windows-runner]].

**A measured-empty-compare is a sufficient regression pass on its own —
a fresh Windows run is not always required.** On #23's regression
(2026-08-13), the Systems Engineer's hand-off explicitly offered "a fresh
Windows run against trunk if you want live confirmation, or a stated 'no
product path moved' if you're satisfied by the compare result — either is
a valid regression pass given the measured empty diff." I took the compare
route: `compare/<passed-sha>...main` showed only `docs/RTVM.md` and
`.claude/agent-memory/**` changed (no `tests/windows/`, `src/`, `samples/`,
`.sln`/`.vcxproj`), so I still ran the two cheap always-re-run checks
(samples byte/LF integrity, `.sln`/`.vcxproj` not gitignored) on the actual
trunk checkout, but did not spend a Windows CI run re-confirming a harness
that had zero product-path diff since its last real PASS. Don't default to
spinning a fresh Windows run out of caution when the compare is empty and
the hand-off has already named the lighter route as acceptable — read the
hand-off for which routes it explicitly sanctions before picking the more
expensive one.

**#11's regression pass (2026-08-14)** had no explicit lighter-route offer
in the hand-off (unlike #23), so I ran the full Linux substitute suite
(56/56 full, 40/40 core-only) plus TP-402 process-level and the two cheap
checks anyway, even though `compare/481c726...main` was product-empty
(only `docs/RTVM.md` + CI/CD memory changed, 2 commits ahead). Treat "no
explicit lighter route named" as the default case requiring the full
substitute-harness run, not just the compare — #23's shortcut was
Systems-Engineer-sanctioned, not a standing default.

**#13's regression pass (2026-08-14)**, same no-lighter-route default
(63/63 full, 47/47 core-only) — but here the compare-against-last-passed-
branch-tip trick from the top of this note needed a correction: `compare/
<issue-13's own branch tip>...main` came back non-empty for files the
branch never touched (`Messages.cpp`, `Reporter.cpp`, `TestFixtures.h`),
because that branch tip predated #12's merge to trunk. The right baseline
for a post-merge regression is **the trunk tip before *this* merge**
(here `e5119a0`, the merge commit's non-branch parent), not the feature
branch's own tip — compare `<pre-merge-trunk-tip>...main` instead, which
came back exactly the touched files (`Solver.cpp`, `main.cpp`,
`SolverTests.cpp`, `docs/RTVM.md`) and nothing else. Use the merge
commit's second parent (`git log --merges` or the CI/CD hand-off's stated
parents) to find it, not the branch-tip SHA a Software/Test Engineer
comment names earlier in the thread.

**#12's regression pass (2026-08-14), same no-lighter-route default (59/59
full, 43/43 core-only), plus a free find worth repeating every time:**
`gh run list --workflow=windows-verification.yml` had a *completed* run
whose `headSha` was the exact trunk tip I was testing (not just a SHA
close to it) — [[windows-evidence-reading]]'s "fair game, no need to
trigger a fresh one" applied literally. Reading its raw `tests.trx` /
`runtime-procedures.json` (not the green conclusion) gave real MSVC
`vstest` discovery+execution (59/59, exit-code-gated) for free, which is
exactly the V-1/DW-1 clause the RTVM rows I was regression-testing list
as outstanding. **Always check for an existing run at the current trunk
tip as part of a regression pass, before assuming Windows evidence is out
of scope for a "Linux substitute" regression** — it can hand you the
platform-specific clause the substitute harness can never itself close,
at zero extra cost.

**#17's regression pass (2026-08-15)**, no lighter-route offer in CI/CD's
hand-off, so full default: 66/66 full driver, 49/49 core-only, plus the
two cheap checks, all clean. `compare/<last-passed-branch-tip>...main`
(`091e914...c33bb1d`) was product-empty (only `docs/RTVM.md` + agent
memory, 14 commits ahead) — here the branch-tip baseline was still valid
because no *other* issue's merge had landed on trunk in between (unlike
#13's gotcha above), so no need to hunt for the merge commit's second
parent this time; worth checking which case applies before assuming one
baseline trick always works. Found a Windows run at the exact trunk tip
again (`31861447621`, `headSha` = `c33bb1d`) — 66/66 vstest, and
`run-procedures.ps1` at 47/55 PASS / 8 NOT-RUN, all 8 the same
already-flagged gaps (TP-900/901 no-2022-image, TP-004/005/006/007/008/
405/507 lacking the interactive-protocol driver) with identical reason
text to the Systems Engineer's own §9.26 note — confirms "same reason,
same TPs" is itself a checkable regression signal, not just "still
failing." Also spot-checked that the exit-code gate from
[[false-pass-from-unchecked-exit-codes]]'s fix is still wired on TP-401/
402/403/406 in this run's JSON, not just that the rows read PASS — the
fix has now held across at least two regression passes since #23.

**#18's regression pass (2026-08-15)**, another #13-shaped gotcha: the
branch tip named in the thread (`c8c93e0`) was **not** the right baseline
— comparing from it showed `tests/windows/lib/Common.ps1`/`run-timing.ps1`
as changed, which is false-positive noise from #19's parallel branch
(already regression-tested on its own issue), not from #18's merge. Used
the merge commit's non-branch parent instead (`git show -s --format='%P'
<merge-sha>`, here `3e7406a`) compared to `main` — came back exactly
`docs/RTVM.md` + agent memory + the one test file #18 actually added, 9
commits ahead. **Always check whether any other issue's branch merged in
parallel before trusting a comment-stated branch-tip baseline** — a
sibling-branch false positive looks identical to a real regression at a
glance. Otherwise standard full-default run: 67/67 full driver, 49/49
core-only, real-binary byte-for-byte match on all four samples, Windows
run found already sitting at the exact trunk tip (no need to trigger a
fresh one) with the identical 47/55 PASS / 8-NOT-RUN signature for a
third consecutive regression pass, exit-code gate confirmed still wired,
and the §9.29/§9.30 heading-collision fix (from CI/CD's flag) confirmed
resolved with no duplicates left in `docs/RTVM.md`.

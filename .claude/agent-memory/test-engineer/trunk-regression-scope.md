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
commit landed after they wrote the comment. Nothing product-bearing differed
either way, but a stated scope is a snapshot of the trunk at writing time, not
of the trunk you test.

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

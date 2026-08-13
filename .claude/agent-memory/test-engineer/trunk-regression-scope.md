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

Also: do **not** re-derive a verdict on items already marked Verified. The
Systems Engineer asked explicitly that Verified items only be checked for
regression, not re-litigated. See [[deliv-inspection-coverage]] and
[[no-windows-runner]].

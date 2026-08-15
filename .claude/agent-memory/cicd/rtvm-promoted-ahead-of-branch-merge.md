---
name: rtvm-promoted-ahead-of-branch-merge
description: "#19 — Systems Engineer pushed the RTVM-504 promotion straight to main before CI/CD merged issue-19, but the branch still carried real, unmerged harness code; not the fast-path docs-only shape, a genuine merge with a pre-split docs/code history"
metadata:
  type: project
---

On #19 (RTVM-504, 2026-08-15), `main` already had two commits
(`6f9b08f` RTVM promotion, `71ca759` Systems Engineer memory) recording
RTVM-504 Approved → Verified with Commit(s) `d4d79b2` — pushed directly to
`main`, not via `issue-19` — by the time the `status:ready-for-commit`
hand-off reached me. First instinct was to check this against
[[fast-path-rtvm-update-nothing-to-commit]] (docs-only, nothing to merge).
That would have been wrong: `git diff --stat` from the merge-base showed
`issue-19` itself never touched `docs/RTVM.md` at all — only
`tests/windows/lib/Common.ps1` (168 new lines) and `run-timing.ps1` (100
changed lines), the actual TP-504 harness code, genuinely unmerged.

**Why this isn't the fast path:** the fast-path shape is "no `issue-<n>`
branch exists / the branch is memory-only, nothing to merge." Here a real
3-commit branch existed with real product-adjacent code the docs promotion
had gotten ahead of. The Systems Engineer's RTVM edit and the Software
Engineer's code lived on two different lines of history that had simply
never touched the same file, so merging them was a clean union: no
conflict, because `docs/RTVM.md` was untouched on one side and
`tests/windows/*` untouched on the other (base `main` state, before either
diverged).

**How to apply:** don't assume "RTVM.md already promoted on main" implies
"nothing left on the branch" — check `git diff --stat <merge-base>
<issue-branch> -- .` (not just `-- docs/`) before reaching for the
fast-path label. If the branch has a non-empty diff outside `docs/` and
agent memory, it's a normal [[branch-and-merge-conventions]] merge; the
RTVM promotion having landed early just means the merge won't touch
`docs/RTVM.md` and the Commit(s) column can stay as the evidence SHA
without needing an update.

**PowerShell-only diff still counts as code for the regression note:**
this branch's only non-docs, non-memory diff was two `.ps1` files, no `.cpp`
or `.vcxproj` changed. Treated it as a real code merge per
[[test-code-only-merge-still-needs-regression]]'s underlying principle
(any `tests/` change, any language) — ran the full g++ build, a `pwsh`
parse-check of all four `tests/windows/*.ps1` files, TP-903's grep, and
the regex-generated native TEST_METHOD driver (66/66, unchanged count,
confirms rather than newly validates since no C++ test file changed) —
and said plainly in the hand-back that regression testing is needed
because this is the harness's first arrival on `main`.

**Why:** two roles both writing to `docs/RTVM.md` at different times
around a merge is exactly the situation [[doc-conflicts-on-merge]] warns
about — this time it resolved itself cleanly because the timing of the
edits happened not to overlap the same lines, but that's luck, not a
guarantee; always check with `git merge-tree` before assuming it.

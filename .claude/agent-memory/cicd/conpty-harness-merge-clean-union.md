---
name: conpty-harness-merge-clean-union
description: "#25 — a 12-commit branch with 10 in-branch Windows-CI diagnostic rounds still merged as a clean union; no conflict shape despite the long history and the flagged RTVM-004 promotion trigger"
metadata:
  type: project
---

On #25 (2026-08-15, ConPTY spike for TP-004/005/006, §9.4 A-4), the
`issue-25` branch had 12 commits of real iterative work (10 rounds of
Windows-CI diagnostics narrowing a console-input-delivery gap, plus a
mid-branch `Merge remote-tracking branch 'origin/main'`) before reaching
`status:ready-for-commit`. Despite that long history, `git merge-tree`
against `main` was a completely clean union — zero conflict markers
across all 9 changed files, including `docs/RTVM.md` (118 lines) and
three different role `MEMORY.md` index appends (software-engineer,
systems-engineer, test-engineer). The branch's own mid-history merge from
`main` had already absorbed anything `main` picked up while the branch
was open, so by the time it reached me there was nothing left to
reconcile.

**A-4 outcome, for context on future ConPTY-adjacent issues:** the spike
closes half of §9.4 A-4 (TP-004 in full, TP-006's cadence/non-blocking
clauses — genuine PASS over a real `CreatePseudoConsole` session) and
converts the other half to a measured V-4 negative (TP-005 in full,
TP-006's stop-response clause — FAIL, isolated to host-written ConPTY
input never reaching the child's console input buffer on this specific
hosted image, confirmed by a true direct-attachment probe with no
`cmd.exe`/redirect wrapper in the chain). Not a product defect —
upstream of `StdinChannel.cpp`/`SolveSession.cpp` entirely.

**RTVM-004 promotion trigger:** the Systems Engineer's RTVM update
(`docs/RTVM.md` §9.34) explicitly flagged that RTVM-004 should promote to
Verified once the evidence tree (Windows CI run headSha `cf67e0d`) lands
on `main` — a rare case where the *next* CI/CD merge confirmation is
named in advance as the promotion trigger. Confirmed with
`git diff --stat cf67e0d <merge-sha> -- . ':!.claude/agent-memory'`
(empty) that the merged tree matches the cited evidence exactly, then
said so explicitly in the hand-back rather than setting Verified myself
— per [[branch-and-merge-conventions]], that's still the Systems
Engineer's write even when the trigger condition was already spelled
out.

**Why this is worth recording:** it would have been easy to assume a
branch with 10+ diagnostic rounds and a mid-branch merge-from-main would
need real conflict resolution work by the time it reached commit. It
didn't — the mid-branch merge had already done that job. Don't skip the
`git merge-tree` preview on the assumption a long branch history implies
a messy merge; check first, every time.

**How to apply:** on any branch with an in-branch `Merge remote-tracking
branch 'origin/main'` commit, expect (but still verify) a cleaner merge
than the commit count alone would suggest — that merge commit already
absorbed trunk drift once.

---
name: partial-tp-group-discharge-and-branch-checkout-gotcha
description: Handling a TP group that only partially discharges several grouped RTVM rows at once (issue #25 ConPTY spike), plus a git-stash-with-pathspec gotcha when switching a fresh main-based checkout onto an existing origin/issue-N branch mid-edit.
metadata:
  type: feedback
---

## Partial discharge across a grouped row set (issue #25, A-4 spike)

§9.26 grouped RTVM-004/501/502/503 under one "still outstanding: automated
harness + V-1 process-level re-execution" cell, because they'd all been
tested together by hand on #17. When the automated evidence finally
arrived (#25's ConPTY harness), it did **not** discharge the group
uniformly:

- RTVM-004 (TP-004: single-shot content+timing check, no repeat count in
  its own text) — genuinely "in full," zero outstanding clauses.
- RTVM-501 (TP-501: "repeat 5 times") — the harness supplied 1 sample.
  Per **V-6**, partial, not "in full" — do not promote on a single sample
  just because it's within tolerance.
- RTVM-502 (TP-502: "expect prompt lines at 15/25/35/45/**55** s ... exactly
  5 prompts") — the harness only captured 4 (session moved to a stop
  attempt before the 55 s mark). Partial, same V-6 reasoning.
- RTVM-503 (TP-503: RTVM-204 step-count sampling per prompt window) — not
  measured by this harness shape at all. Untouched.
- RTVM-006 similarly split: its own substantive text (never blocks,
  unanswered lapses) got clean automated evidence, but TP-006's own
  written procedure also demands a subsequent accepted stop response,
  which failed for an unrelated infra reason — so the *row* still isn't
  "in full" even though its *substance* is now well-evidenced.

**Why this matters:** a shared "still outstanding" cell for a grouped row
set is a summary, not a promise that one new evidence source clears the
whole group identically. When new evidence lands against a grouped row
set, re-derive each row's own TP text and check the *literal* ask (repeat
counts, exact sample windows, which sub-clause is which row's) before
writing a single blanket "discharged" note — see
[[rtvm-conventions]] for the base ID/TP conventions this extends.

**Also confirmed:** when a row's clauses ARE all fully discharged but the
evidence sits on an unmerged issue branch (not literally on `main` the
way §9.12's regression pass was), the correct move is the §9.10.2
pattern — leave status at **In Test**, Commit(s) unchanged, and add an
explicit flag that the *next* CI/CD commit-confirmation should promote it
straight to Verified without a further Test Engineer round, since nothing
remains for a regression pass to find. Don't conflate "evidence gathered
on a branch that's tree-identical to trunk for the tested code path" with
"evidence gathered on trunk" — only the latter promotes immediately per
[[no-code-measurement-still-routes-to-cicd]]'s sibling precedent (§9.12).

**How to apply:** whenever an issue's evidence table covers more than one
RTVM row under one combined "outstanding" note, split the write-up back
into one line per row before recording anything, and match each row's own
TP text word-for-word against what was actually run.

## `git stash push -- <pathspec>` on a dirty index can revert unrelated files

Sequence that went wrong: created a fresh branch from `origin/main`,
edited `docs/RTVM.md` in the worktree (unstaged), then realized the real
work lived on `origin/issue-N` (a different, divergent branch) and needed
`git reset --soft origin/issue-N` to move there. That reset left the index
holding a large diff against the new HEAD for files the worktree didn't
actually have yet (everything `issue-N` added). Running
`git stash push -- docs/RTVM.md` at that point, then
`git checkout origin/issue-N -- .` to pull in the real tree, then
`git stash pop` — the pop reintroduced the *entire* pre-existing
stale-worktree diff (deleting files `issue-N` had added), not just
`docs/RTVM.md`, because the index was dirty in an unrelated way when the
stash was taken.

**Fix used:** `cp` the one file with real edits to `/tmp`, `git reset
--hard origin/issue-N` to get a byte-clean copy of the real branch, then
`cp` the saved file back in and diff-check before committing. Cheaper and
safer than trying to reason about a stash interacting with a
mid-reset dirty index.

**How to apply:** when a run's edits started on the wrong base (e.g. a
fresh checkout from `main` when an `origin/issue-N` branch with the
real prior work already exists — check for it with `git fetch origin
issue-N` *before* editing, not after), don't reach for `git stash` with a
pathspec while the index is mid-reset. Save the edited file(s) out of the
tree, hard-reset to the correct branch, then reapply just those files and
verify with `git status`/`git diff --stat` before committing.

---
name: verification-platform-trap
description: The target platform and the pipeline's verification platform can differ — check it while writing the RTVM, know what the agent token can do about it, and why a passing test means In Test rather than Verified
metadata:
  type: feedback
---

# Verification platform ≠ target platform

Check, while writing test procedures, **what machine will actually execute
them**. On SudokuSolver every procedure was specified against Windows + VS 2022
while every agent run executes on Ubuntu with no MSVC — so most of the
verification had no home, and nobody noticed until the scaffold was tested
(issues #5, #23, 2026-08-07).

**Why:** a test procedure reads as executable because it is well specified. Its
executability is a property of the *pipeline*, not of the procedure, so no
amount of care writing the RTVM surfaces the gap. It surfaces at the first
build, which is the most expensive moment to find it.

**How to apply:** when the deliverable names a platform, toolchain or IDE, add
one pass over the TP list asking "on what machine does this clause run?" before
declaring the RTVM Approved. Where a clause can't run in-pipeline, say so in
the RTVM at once (a §9-style ledger of executed vs. outstanding clauses per
requirement), and raise the *process* question with the Solutions Architect
early — it is above the requirements level and it will not resolve itself.

## The resulting policy on this project (SA, issue #23)

`docs/PROJECT_DEFINITION.md` §7.1, V-1…V-7. The load-bearing ones:
substitute-toolchain results are **evidence, never a verdict**; partial
execution is recorded as partial; a client-acceptance fallback is permitted
only as a short, individually-justified, agreed-in-advance list. "Some of it
will have to be done by hand" is not a decision.

## Measured limits of the agent token — do not re-derive these

Probed live on 2026-08-07 with the relay App installation token:

- **Pushing any file under `.github/workflows/` is rejected** — "refusing to
  allow a GitHub App to create or update workflow … without `workflows`
  permission". No agent of any role can add or edit a workflow.
- **`gh workflow run` returns HTTP 403** — the installation has `actions: read`
  (listing workflows and runs works, and reading run logs/artifacts works) but
  not `actions: write`. No agent can dispatch a workflow either.

**How to apply:** any plan whose critical path is "add a CI job" is blocked on
the repository owner, so design *around* the API the token does have — a
`push`-triggered workflow needs no dispatch permission, which is why W-3 chose
it. And when handing the block up, ship the finished artifact somewhere
pushable (`docs/ci/<name>.yml`) so the human's task is one copy, not a design
job. Reduce the ask to the single smallest permission that unblocks it and say
which permissions are explicitly *not* being asked for.

## The `status:ready-for-rtvm-update` fast path is not "mark it Verified"

Two things gate Verified here (`docs/RTVM.md` §9.2's rule): every clause of the
procedure executed on the *real* toolchain, **and** CI/CD's trunk SHA in the
Commit(s) column. A passing Test Engineer run on the Ubuntu runner satisfies
neither on its own. So the fast path moves the item to **In Test**, and Verified
waits for the CI/CD hand-back — and even then stays In Test if a clause is
still unexecuted.

**Why:** a feature's procedure routinely contains end-to-end clauses that need
components built by *later* issues (TP-101/TP-106 here are worded "runs
end-to-end to `S-EASY` with exit 0", which needs the solver and the reporter).
The unit half passing is a real pass and should not be downgraded, but calling
it Verified means nobody ever re-runs the other half.

**How to apply:** on every fast-path update, add a clause-level row (§9.2's
shape; §9.5 for the parser) saying what ran and what did not, and write an
explicit **re-run trigger** naming the issue whose merge makes the missing
clause reachable. Vertically-sliced RTVM items get verified in two passes; plan
for the second one in writing, because nothing else in the pipeline will
remember it.

See [[requirements-traps]], [[sudoku-solver-project-context]],
[[doc-state-across-branches]].

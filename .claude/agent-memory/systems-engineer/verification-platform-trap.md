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

## Scope a post-merge regression pass with a `compare` call, not a guess (2026-08-13)

On the CI/CD commit confirmation for a feature branch, ask the API what
actually moved before routing the Test Engineer:
`gh api repos/OWNER/REPO/compare/<merge-sha>...main --jq '[.files[].filename]'`.
On issue #6 the answer was `.claude/**` only — `src/` and `samples/` on trunk
were byte-identical to the branch commit the 95-assertion pass was taken on.

**Why:** "needs regression testing" from CI/CD is a routing flag, not a scope.
Handed on unqualified it invites a full re-execution of a procedure that was
just executed, and the shallow clone (`git rev-list --count HEAD` = 2) means
local `git diff` against the merge SHA silently fails rather than answering.

**How to apply:** write the measured file list into the §9.x ledger and state
the regression question in one sentence ("did the merge disturb anything", not
"does the feature work"), naming the specific clauses to re-run. Also: when
recording the SHA, resist the earlier hand-off comment's own optimism — mine
said RTVM-100 "can then move to Verified subject only to the MSVC gap", which
is self-contradictory under §9.2. An outstanding clause is an outstanding
clause; the SHA populates the column, it does not promote the status.

Confirmed a third time on #8 (2026-08-13): `compare/<merge-sha>...main` and
`compare/<branch-tip>...main` both returned **only** `.claude/agent-memory/**`.
Run both — the branch-tip comparison is the one that actually answers "is trunk
byte-identical to the tree the PASS was taken on", and it costs one extra call.

**Take the measurement *after* your own push, not before.** On #8 I quoted a
three-file list in the hand-off; by the time the Test Engineer re-derived it, it
was five — the two extras were my own commit (`docs/RTVM.md` + a memory file),
pushed after the comment was drafted. The conclusion held, but the figure was
stale by one commit at the moment it was written. Either push first and then
measure, or state the comparison as "excluding this run's own doc commit".
Corollary in the other direction: **re-derive any scope figure handed to you**;
that is what caught this.

### The Commit(s) column is mine to write, not CI/CD's (2026-08-13, #8)

My #8 hand-off said "Commit(s) is left blank for CI/CD to fill". CI/CD declined
and handed it back, correctly: the standing convention is that **CI/CD reports
the SHA in the issue thread and the Systems Engineer writes it into
`docs/RTVM.md`**, so exactly one role writes the matrix.

**Why:** two writers on the same column is how the RTVM and the commit history
end up disagreeing about what shipped — and the row also needs a *status*
judgement (§9.2's two-part rule) that only I hold.

**How to apply:** never delegate a Commit(s) write in a hand-off comment. Say
"report the SHA and hand back; I record it," which is the round trip anyway.
Also expect the reported branch SHA to be a commit or two behind the merged
head — lock releases and agent memory files land after the hand-off comment is
posted. Reconcile the two SHAs in the ledger rather than assuming a mismatch is
an error.

## Closing the issue ≠ promoting the requirement (2026-08-13, #7)

The client may cut a feature issue short ("just merge and close this out").
Close the issue — but the requirement's status lives in `docs/RTVM.md` and is
governed by §9.2, not by the issue's state. On #7 all three DATA-OUT items
stayed **In Test** with the trunk SHA recorded while the issue closed.

**Why:** the re-run trigger in the §9.x ledger is what brings the outstanding
clauses back (#18, #8/#12, #10 here); it is keyed to the *later* issues, not to
this one, so closing loses nothing. Silently promoting to Verified to make the
closure look tidy would delete the only record that half a procedure never ran.

**How to apply:** when closing early, write one paragraph in the ledger saying
*who* instructed the close, *what had already been executed* at that point, and
that the status is deliberately unchanged. Then the closure reads as a decision
rather than as an oversight six issues later.

## The second `ready-for-rtvm-update` on an issue is the terminus, not the fast path (2026-08-13, #6)

A feature issue gets handed back with `status:ready-for-rtvm-update` **twice**:
once for the pre-merge test PASS (→ CI/CD with `status:ready-for-commit`, the
documented fast path) and once for the post-merge *regression* PASS. The second
one has no build to commit — the code is already on trunk — so routing it to
CI/CD would be a no-op merge. Record the regression result in the §9.x ledger,
comment, and **close**; that is the chain complete.

**Why:** the fast-path rule assumes there is a branch waiting to be merged.
After CI/CD's hand-back and the regression round trip, the only artifact left is
the Systems Engineer's own doc edit, which goes straight to `main` (the
`issue-N` branch convention covers feature code, and #6/#7's close-out commits
`d07b853`/`c69073f`/`fc9e891` all landed on trunk directly).

**How to apply:** read the thread, not just the label — if CI/CD has already
reported a trunk SHA above you, you are in the terminus case. Write the
regression result as a positive result ("the merge disturbed nothing", with the
measured `compare` file list), keep the statuses where §9.2 puts them, and close.

Applied again on #8 (2026-08-13, §9.7.2). I had started down the fast path —
cut an `issue-8` branch for the close-out edit and drafted a CI/CD hand-off —
before this entry corrected it. Worth stating why the fast path is actively
wrong here rather than merely redundant: it would have merged a docs-only branch
to trunk, and CI/CD's own rule ("a trunk merge needs regression testing") would
then have produced a *third* regression round trip over a change containing no
`src/`, `tests/` or `samples/` path. The terminus case exists to stop that loop.

## Two verification conventions worth carrying to the next project

- **A green build is not evidence when the assertion is a `static_assert`.** A
  deleted or vacuous compile-time guard compiles just as happily as a real one.
  Require the mutation and its observed effect to be stated, or treat the clause
  as unverified. (One recorded non-defect: a *private* default constructor does
  not trip `!std::is_default_constructible_v` — the trait is evaluated from
  outside the class.)
- **Mutation evidence is not required on a regression pass** over unchanged
  code. Re-deriving it re-tests the feature instead of the merge. Say so in the
  hand-off, or the Test Engineer will reasonably produce it anyway.

See [[requirements-traps]], [[sudoku-solver-project-context]],
[[doc-state-across-branches]].

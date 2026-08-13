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

### Update 2026-08-13: the permission wall is permanent, and it should shape the design

The client resolved it by copying the file in by hand. The load-bearing
correction, from the owner: **the "grant the App `workflows`" option was never
available** — the App declares only Contents, Pull Requests and Issues, and an
installer cannot grant a permission an app has not *declared*. So `.github/`
is permanently out of reach, not one settings toggle away.

**How to apply.** Check what an app *declares*, not just what a permission
would do, before offering it as an option — offering an unavailable option
costs a round trip and misrepresents the trade-off. Then design for the wall:
put every line that can move into agent-writable script hooks the workflow
merely *invokes* (`tests/windows/*.ps1` here, project rule W-10), so the
workflow is only build → locate → invoke → summarise → publish. And **batch**
workflow edits into one copy-and-commit with a dated `PENDING — NOT YET
INSTALLED` block at the head of the source file (W-11); the maintained source
and the installed copy will diverge, and that diff is the queue.

## A green CI job proves the job ran, nothing else — read the steps

The first Windows run was green with a step that had failed (`continue-on-error`)
and two that never ran. Two things fell out of actually reading the log and
artifact instead of the tick:

- **A CI summary must be able to say FAIL, not just PASS/NOT-RUN.** Mine keyed
  each row on "did an output file appear", so a step that ran and *errored*
  rendered identically to one never attempted — a broken `vstest.console.exe`
  invocation read as a tidy `NOT-RUN` for two runs and would have been recorded
  as "automation route confirmed". Understating a failure as an absence is the
  mirror image of overstating a pass, and it is the row nobody chases. Key rows
  on the step's own `outcome` as well as its evidence file.
- **Never quote a hosted image's specs from an earlier run, or from your own
  assumption.** `windows-latest` on 2026-08-13 was `win25-vs2026` — Windows
  Server 2025 with **Visual Studio 2026**, no VS 2022 anywhere on it — where
  the RTVM interpretation I'd written said Server 2022 and the whole team had
  assumed VS 2022 was present. Have every run print its own machine block and
  read figures only from the same run (W-9); name the runner *label* in a
  requirement, never an image.

**The requirements consequence is worth generalising:** when a deliverable
names an IDE, split the requirement into the *artifact* claim and the *IDE
load* claim before deciding what CI can discharge. A newer IDE building the
project is real evidence for the toolset (the v143 / MSVC 14.44 toolset ships
side-by-side inside VS 2026, so the binary is the same one the client's build
would emit) and **no** evidence for "opens without a migration prompt" — that
is forward compatibility, and the requirement runs backward. Recorded as
`docs/RTVM.md` §7 I-17.

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

## An SDD-specified test harness can go unbuilt while every feature still passes (2026-08-13, #9)

`docs/SDD.md` §3.3 assigned TP-001…009, TP-401…406 and TP-500…507 to end-to-end
tests spawning the exe through a `sudoku::test::ProcessRunner` helper. At the
first issue that actually needed it, the helper **did not exist** — the Software
Engineer declined to build it (Windows-only `CreateProcess`, undebuggable pipe
deadlocks for a Test Engineer who cannot edit files) and hand-ran the three
procedures instead. They genuinely passed. Nothing in the pipeline flags this:
the RTVM says "In Test", the thread says PASS, and no committed test will ever
re-run it.

**Why:** the §9.x ledger asks "which clauses executed?", not "will they execute
again?". A hand-run procedure and a procedure backed by a test method look
identical in that column, and the difference only bites at the first regression
pass, when the evidence turns out to be unrepeatable.

**How to apply:** whenever an infrastructure component named in the SDD (a test
harness, a fixture loader, a mock) is a prerequisite for a whole *class* of
procedures, give it its own issue rather than letting each feature issue
re-decide it, and require the same platform seam the product code uses so the
procedures execute in-pipeline. In the ledger, distinguish **executed and
automated** from **executed by hand** explicitly, and write the rule that a
requirement must not reach Verified on hand-run evidence once the harness exists.
Don't gate the whole remaining feature set on the harness issue — that serialises
the pipeline, and hand-run evidence is real evidence. #24 here, deps on #9 only.

**Confirmed at the very next pass (2026-08-13, #9 regression).** The post-merge
regression pass over those same three procedures was *also* hand-run, because
the harness still did not exist — so the fragility compounds rather than being
absorbed: two consecutive passes, neither reproducible by anything committed.
Say so explicitly in the ledger row the second time, or "passed twice" reads as
strengthening evidence when it is the same unrepeatable evidence twice.

## Split "re-execute under the real toolchain" into compile and execute (2026-08-13, #9)

Once a real-toolchain build starts running in CI, the outstanding clause phrased
as "MSVC re-execution" stops being one thing. At #9 it decomposed into: *does the
shipping platform-specific code compile under the real toolchain* — **yes**, the
`_WIN32` seam was compiled clean under MSVC 14.44/v143 for the first time — and
*do the test methods get discovered and executed under the real test runner* —
**no**, at any commit, because the discovery step had been broken since it was
written.

**Why:** an undifferentiated phrase in a §9.x "still outstanding" column both
understates what has been achieved (the shipping code now provably compiles) and
overstates what remains (people read it as "nothing has run"). Neither error is
visible until someone tries to decide whether a requirement can be promoted.

**How to apply:** when the first genuine target-platform run lands, rewrite the
outstanding clauses across the whole ledger into the two halves and name which
half each requirement still owes. Keep reporting the measurement rather than
moving a status — compile evidence does not promote a `Test`-method requirement,
because its procedure asserts assertions running, not code compiling. And read
the raw log: a step whose job concluded `success` can carry `##[error] … exit
code 1` in its own log, which is how a broken discovery step survives three runs.

## A `status:ready-for-rtvm-update` can land on a process issue, not just a feature issue (2026-08-13, #23)

The fast path's wording ("this is not a new requirement to define — the Test
Engineer's test passed") assumes an `[RTVM-014]`-style issue. #23 is the
standing "verification environment" process issue, and the label still showed
up there once the Test Engineer's harness-script fix passed — because the
harness itself (`tests/windows/*.ps1`) has RTVM consequences (§9.4 rows,
DW-numbered defects) even though it traces to no single requirement.

**How to apply:** don't discard the fast path just because the issue title
isn't `[RTVM-nnn]`. Find the §9.x rows the passing evidence actually bears on
(here: DW-1's closure, §9.4 A-2/A-3/A-5) and update those, same discipline as a
feature row — evidence in, verdict from Test Engineer, no status promoted on my
own authority beyond what's explicitly named.

## A harness fix can surface false-PASS defects worse than the bug it fixes

Fixing a launch-failure bug (`Invoke-Sudoku`'s stdin default throwing) on #23
uncovered two downstream defects that had been silently reporting **PASS**
against the client's own headline requirement (the 10-second performance
budget) using the *crash latency* of a process that never launched, because
`$withinBudget` checked only the ceiling and never the exit code. A
"contains-none-of-these-substrings" style check has the same trap: an empty
string from a dead run trivially passes it.

**Why:** any PASS/FAIL check built on "the absence of the bad thing" rather
than "the presence of the expected thing, from a run that actually reached the
state being asserted" reads as evidence for exactly nothing while looking
identical to a real pass. This is a sharper version of DW-2 (FAIL rendering as
NOT-RUN) — here a FAIL rendered as PASS, which is strictly worse under W-2/V-1.

**How to apply:** when reviewing (or specifying) any evidence-harness check,
ask "what does this check read as if the thing under test never ran at all?"
before trusting a PASS. Require every timing/behavioural check to also assert
the run reached its expected exit code, not just the metric in question.

## A CI/CD commit confirmation can also land on a process issue with no Commit(s) cell (2026-08-13, #23)

Same shape as the fast-path note above, one step later in the loop. CI/CD merged
`tests/windows/*.ps1` to trunk (`bd43de2`) and handed #23 back with "record the
SHA in the Commit(s) column and decide next steps" — the default instruction,
written for an `[RTVM-nnn]` feature issue with exactly one matrix row to update.
#23 has none: the harness traces to no single `RTVM-nnn` requirement, so there
is no Commit(s) cell to populate.

**How to apply:** record the merge SHA in the relevant §9.x narrative section
instead (here, appended to §9.1.6, the same subsection the earlier fast-path
update wrote), and explicitly say in both the doc and the hand-off that no
matrix row's Status/Commit(s) moved. Still honor CI/CD's regression flag —
route to Test Engineer — but scope it with a `compare` call
(`[[verification-platform-trap]]`'s existing rule) between the last-verified
branch tip and current trunk before asking for a fresh run; on #23 that
returned only `docs/RTVM.md` + agent memory, so the regression pass is a
narrow confirmation, not a re-verification from scratch.

## DW/A/I/V/W numbers: allocate from trunk, and check for the collision pattern

Confirmed again on #23 that new evidence defects continue the *trunk* DW
sequence (DW-1, DW-2 already on `main` → new ones are DW-3, DW-4), per the
numbering rule §7 records after the #9/#23 `I-17` collision (see
`rtvm-conventions.md`). Applies identically to every prefixed series in
`docs/RTVM.md` — check trunk's own table before allocating, not a branch's
copy, even when (as here) the branch's `docs/RTVM.md` happens to be identical
to trunk's.

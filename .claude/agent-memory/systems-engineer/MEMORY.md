# Systems Engineer — memory

## RTVM conventions

- [RTVM conventions](rtvm-conventions.md) — ID blocks, TP numbering 1:1 with requirement number, and the §6/§7/§8 sections every RTVM here carries.

## Requirements patterns and traps

- [Requirements traps](requirements-traps.md) — untestable thresholds, a performance budget that defeats its own safety-net requirement, fixtures with overlapping faults.
- [Blocked without a Project Definition](blocked-without-project-definition.md) — don't write requirements before scope is confirmed; escalate instead.
- [Verification platform trap](verification-platform-trap.md) — target platform ≠ the platform the pipeline can test on, the measured limits of the agent token, and why the fast path means In Test, not Verified.
- [Doc state across branches](doc-state-across-branches.md) — an RTVM/SDD section may live only on an unmerged `issue-N` branch; check before rewriting it.
- [Implementation plan decomposition](implementation-plan-decomposition.md) — vertical-slice ordering, when to group RTVM items into one issue, and why no-work requirements still need one.
- [Pipeline label traps](pipeline-label-traps.md) — a hand-removed `status:on-hold` orphans an issue from the dependency sweep; how to handle a feature issue with an empty thread.
- [Fast-path promotion after SHA recorded](fast-path-promotion-after-sha-recorded.md) — SHA already in Commit(s), later regression PASS on a tree containing it promotes In Test → Verified immediately; still hand off to CI/CD even for a docs-only diff.
- [Second ready-for-rtvm-update closes directly](second-ready-for-rtvm-update-closes-directly.md) — a repeat regression-pass handoff that discharges nothing (no promotion) closes the issue outright, no CI/CD round trip; only route to CI/CD when a clause is actually discharged and a row promotes.
- [No-code measurement still routes to CI/CD](no-code-measurement-still-routes-to-cicd.md) — a measurement-only issue's first Approved→Verified promotion takes the fast path to CI/CD even with a docs-only diff; don't confuse with the repeat-handoff close-directly case.
- [Commit(s) SHA recorded is the merge commit](commit-sha-recorded-is-the-merge-commit.md) — when CI/CD offers a pre-merge evidence SHA vs. its own `--no-ff` merge SHA, record the merge SHA; verify against prior rows' parent count, don't trust a CI/CD comment's claimed convention at face value.
- [Verified on first commit confirmation, not gated by V-1](verified-on-first-commit-confirmation-not-gated-by-v1.md) — the first commit-confirmation hand-back promotes straight to Verified even with regression testing still pending; don't hold at In Test the way older precedent did.
- `rtvm-conventions.md` also covers: §9 subsection numbers collide across branches just like I-/W-/V-/DW- IDs (allocate from trunk); a regression pass on an already-Verified row has nothing to discharge — record fresh evidence as a pointer, not a promotion; the first-pass In Test promotion commit lands on the issue's own branch, not main (only the later SHA-recording touch is direct-to-main).
- [Shallow clone / unrelated histories](shallow-clone-unrelated-histories.md) — `git fetch --unshallow` before merging trunk into an issue branch, or a stale-branch artifact looks like a real conflict.
- [Commit-confirmation bookkeeping pushes direct to main](commit-confirmation-pushes-direct-to-main.md) — the RTVM.md update that records CI/CD's merge SHA is a single-parent commit straight on `main`, not another `issue-N` branch + CI/CD merge cycle.
- [Standing spike instructions can go unfulfilled](standing-spike-instructions-can-go-unfulfilled.md) — a ledger row naming "attempt this on #N" isn't self-enforcing; grep the RTVM for the issue's own number before writing the ledger entry, and reassign to a new issue rather than let it go stale. Also: a row with zero automated evidence for one shape doesn't ride the "first commit confirmation promotes to Verified" precedent just because the rest of the feature passed, and check branch-vs-main *before* the first commit, not after.

## Project context

- [SudokuSolver project context](sudoku-solver-project-context.md) — client ask, the 2026-08-07 scope revision numbers, and the legacy-docs trap.
- [SDD architecture decisions](sdd-architecture-decisions.md) — why the console interrupt needs no threads, the non-blocking-stdin dispatch, solver/test-framework/CRT choices.

## Documentation index

- `docs/PROJECT_DEFINITION.md` — Solutions Architect's scope (authoritative; the only source of scope).
- `docs/RTVM.md` — requirements, test procedures, test fixtures (§6), interpretations (§7), SDD carry-forwards (§8).
- `docs/SDD.md` — architecture, coding standards, build/toolchain conventions.
- `docs/IMPLEMENTATION_PLAN.md` — build sequence and the source of every downstream issue.

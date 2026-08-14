---
name: pipeline-label-traps
description: Removing status:on-hold by hand orphans an issue from dependency-check.yml's sweep — plus how to read a feature issue that arrives with no comment on it
metadata:
  type: project
---

# Label-state traps in this relay

Learned 2026-08-07 (issue #9, `[RTVM-001]`).

## `status:on-hold` removed by hand = the issue leaves the automation

`dependency-check.yml` starts from `gh issue list --label "status:on-hold"`.
It only ever *removes* that label; it never adds it. So an on-hold issue whose
label is cleared manually — by a human tidying labels, or by an agent handing
it forward early — is invisible to the sweep from then on. It will **never** be
released automatically, even after every declared dependency closes. The
failure is silent: the issue just sits there looking assigned.

**Why:** the sweep's query is the only entry point; there is no reconciliation
pass that re-derives hold state from the `## Dependencies` block.

**How to apply:** if a feature issue reaches you with unsatisfied dependencies,
the corrective action is to **restore `status:on-hold`** and remove the
`agent:*` label — not to hand it forward and not to hold it yourself. That is a
legitimate single-command handoff even though it adds a `status:*` rather than
an `agent:*`; per `.github/AGENT_LABELS.md` an on-hold issue carries no
`agent:*` label by design. Say in the comment that the deviation is deliberate.

## A feature issue arriving with an empty comment thread

Every legitimate route into an `[RTVM-014]` issue for this role leaves a comment
first — a Software Engineer query, a Test Engineer pass, a CI/CD commit
confirmation. An empty thread means a manual relabel, i.e. nobody has stated
what they want.

**How to apply:** don't invent a mode. Check the timeline
(`gh api repos/OWNER/REPO/issues/N/timeline`) to see who relabelled and when,
check whether the declared dependencies are actually satisfied, verify the
issue body's requirement text still matches `docs/RTVM.md`, then restore the
correct label state and ask the person who relabelled — on the thread — what
they intended. Escalating a stray label click to the Solutions Architect costs
a round trip and they can't read the intent either; the user is the top of the
ladder and is right there.

## Verify a Finish-Start dependency is real before touching it

Before restoring or relaxing a dependency, re-read the *test procedures*, not
the requirement text. #9's deps looked heavy (`#5`, `#8`) until TP-001/002/003
and TP-400 confirmed all four assert the solved grid on stdout — unbuildable
and untestable without the solver. Transitive chains count: #9→#8→{#6,#7}→#5
means #9 only has to declare #5 and #8.

See [[implementation-plan-decomposition]], [[verification-platform-trap]].

## Resolved: Test Engineer stays blocked from writing `tests/windows/*.ps1`

Raised on #23 (2026-08-13, relayed by Software Engineer on Test Engineer's
behalf), decided the same day. W-10 put Windows procedure scripts under
`tests/windows/` on the premise that whoever owns "what does this procedure
check" (Test Engineer) could revise them without a permission round trip.
`scripts/guard-test-engineer-writes.sh` blocks every Test Engineer `Edit`/
`Write` outside `.claude/agent-memory/test-engineer/`, with no carve-out for
`tests/windows/` — so every revision was still a Software Engineer round trip.

**Decision: no allow-list added.** The guard's own header comment states its
purpose unconditionally — a code change must always originate from, and be
visible to, the Software Engineer; Test Engineer reports problems, it never
patches around them. That is a *separate* wall from the one W-10 was written
to remove. W-10's round trip is the **repository-owner** wall
(`.github/workflows/`, gated by V-10 — a permission no agent holds); moving
procedure logic into `tests/windows/` closes that one specifically. It was
never meant to also waive the deliberate Test-Engineer/codebase authorship
boundary. Software Engineer remains sole author of `tests/windows/*.ps1`,
same as every other repository file; Test Engineer hands over a full spec
(parameters, evidence contract, per-check pass/fail rule) and Software
Engineer implements it — a bounded, already-budgeted cost, not the
open-ended owner round trip V-10 exists to avoid. Written up in
`docs/RTVM.md` §9.1.3 next to W-10.

**How to apply:** when two guard rails both happen to gate the same file
path, don't assume relaxing one implies the other should relax too — check
each guard's *own stated reason* before touching it. `docs/ci/` (owner-gated)
and `tests/windows/` (Test-Engineer-gated) are enforced by unrelated
mechanisms with unrelated justifications, even though both currently block
the same two files.

## Stray relabel that raced the dependency-check sweep, not a query

Seen 2026-08-14 (issue #16, `[RTVM-203]`/`[RTVM-204]`). Human relabeled a
still-on-hold feature issue to `agent:systems-engineer` + `status:in-progress`
without removing `status:on-hold` and with no comment — same empty-thread
signature as above, but here the twist was *why*: the manual relabel landed
~27s **before** its last Finish-Start dependency actually closed, i.e. one
scheduled sweep too early — the very next `dependency-check.yml` run would
have released it to `agent:software-engineer` on its own.

**How to apply:** when you hit this shape, check dependency state *as of
now*, not as of the relabel timestamp. If every declared dependency is
closed by the time you look, there's no real ambiguity left to ask about —
restore the state the sweep would have produced (drop
`status:on-hold`/`status:in-progress`/the stray `agent:*`, add
`agent:software-engineer`) yourself rather than opening a round trip for
a question nobody actually has an answer to. Say so in the comment and
invite a reopen with a stated question if the relabel meant something else.
Only fall back to "ask on the thread and wait" (the general rule above) when
a dependency is genuinely still open.

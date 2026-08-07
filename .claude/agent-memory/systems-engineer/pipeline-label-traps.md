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

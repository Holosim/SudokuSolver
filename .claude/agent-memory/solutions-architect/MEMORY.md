# Solutions Architect — memory

Durable knowledge only: product decisions, client and stakeholder
context, and questions that keep recurring. Task-by-task detail belongs
on the issue itself, not here. Curate this file as it grows — date each
entry, keep it terse, and fold near-duplicates together.

## Product concepts

<!-- Vision and end-to-end user-flow decisions, organized per product
     line (VR HMD gaming interaction, gesture-tracking gloves with
     embedded audio, video jukebox player/controller). Note anywhere two
     product lines share a UX pattern or interaction model worth
     reusing rather than re-deriving. -->

## Client / stakeholder context

<!-- Constraints, preferences, and non-negotiables the client has
     stated, grouped by product line where they diverge. -->
- 2026-08-04 — The client briefs in one sentence and expects the architect to
  interview for the rest. Their own `docs/Workflow.txt` §2 mandates "question
  all gaps, challenge all assumptions, 5 W's" — so a thorough kickoff
  interview is the expected behaviour, not overreach.
- 2026-08-04 — The client names their IDE in the brief. Treat named tooling as
  a deliverable requirement about the artifact, not an incidental build detail
  — see [[deliverable-requirements-pattern]].
- 2026-08-04 — **This client answers scope interviews by editing the document
  and committing it, not by commenting on the issue.** When re-triggered with
  no new issue comment, diff/read `docs/PROJECT_DEFINITION.md` before assuming
  nothing happened — their `[PROPOSED]`→`[CONFIRMED]` flips and inline
  additions *are* the reply. They also add scope in their own voice inside
  existing lines (SN-5 grew an abort-prompt clause this way), so read the whole
  doc rather than only the items you flagged as open.


- 2026-08-07 — The client *does* also comment directly on the issue when changing
  scope after approval (timing revision on #1). So: check both the thread and the
  document diff each run — neither channel alone is reliable.
- 2026-08-07 — The client asks engineering questions directly of the architect
  (multi-threading vs. simpler interrupt). Don't answer them —
  see [[architect-owns-what-not-how]].

## Patterns worth reusing

- [[deliverable-requirements-pattern]] — named IDE/toolchain in a brief is a
  deliverable requirement, captured separately from features.
- [[architect-owns-what-not-how]] — client *how* questions become documented
  architecture-discovery items for the Systems Engineer, never architect answers.
- [[verification-environment-policy]] — build platform ≠ verification platform:
  decide it in writing early, never verify on a substitute toolchain.

## Open questions log

<!-- Ambiguities that have reached this role more than once. If the same
     kind of question keeps showing up, the concept doc for that product
     line probably needs to address it up front next time. -->

## Decisions made

<!-- Date — decision — why, one line each. This is the log other roles
     point back to when a past decision gets questioned later. -->
- 2026-08-04 — Answered a Systems Engineer RFI with a **draft** `docs/PROJECT_DEFINITION.md` marking every unconfirmed item `[PROPOSED]` rather than deciding on the client's behalf — proposals with recommended defaults let the client confirm in one reply without me inventing intent.
- 2026-08-04 — Recommended-default form for scope interviews: put every open decision to the client *with* a recommended answer, so silence-cost is low and a single "all defaults" reply unblocks the pipeline.
- 2026-08-04 — Algorithm choice and test-framework choice are explicitly **not** architect decisions on this project; redirected to the Systems Engineer as *how*, not *what*.
- 2026-08-04 — When the client adds a scope clause without numbers ("prompt intermittently so the user can stop it"), I supply the concrete thresholds myself (5s / repeat 5s / exit code 3) rather than starting another interview round. A vague requirement is untestable; a stated number is correctable in one line. Only the *what* though — how the solve becomes interruptible stayed with engineering.
- 2026-08-04 — Any user-facing prompt on this project must carry a "must not hang a non-interactive/scripted caller" constraint, because ST-4 (scripted caller) is confirmed. Applies to every future interactive addition, not just the solve prompt.
- 2026-08-07 — Long-solve timings revised by the client: budget **10 s** (was 1 s), first prompt **15 s** (was 5 s), repeat **every 10 s**, and the solve must keep running while a prompt is up. Deliberate 5 s gap between budget and first prompt so a marginal overrun never nags.
- 2026-08-07 — Verification environment (issue #23): scope unchanged (Windows/VS 2022 stands), but nothing may be marked Verified on a substitute toolchain, Windows-only clauses must actually run on Windows, and "accept the gap" is rejected as a blanket policy — see [[verification-environment-policy]] and `docs/PROJECT_DEFINITION.md` §7.1.
- 2026-08-07 — Issue #23 came back blocked on a **repository-owner action no agent can perform** (workflow file / dispatch permissions). Put it to the client as V-8 (two sufficient options, recommending the permission grant) plus V-9 (declining both is itself a scope decision needing sign-off, not silence) — see [[verification-environment-policy]] and `docs/PROJECT_DEFINITION.md` §7.1.1. Pattern: when a blocker needs a human capability, name the exact action, give ≥1 zero-permission fallback, and price the do-nothing option.
- 2026-08-07 — Continuing is the *default* answer to any progress prompt on this project, and prompts/diagnostics go to **stderr** while stdout carries only the result. Both follow from ST-4: a non-blocking prompt plus a clean stdout means an unattended run can never hang or need text filtering. Apply to any future prompt, not just the solve one.


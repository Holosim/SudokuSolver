---
name: blocked-without-project-definition
description: How to handle being routed a requirements-breakdown issue before docs/PROJECT_DEFINITION.md exists — escalate with a structured RFI, never fabricate line items
metadata:
  type: feedback
---

When routed a breakdown/RTVM issue while `docs/PROJECT_DEFINITION.md` does not
exist: **escalate to `agent:solutions-architect` with `status:blocked`, and make
the escalation a numbered RFI grouped by functional area** — not a bare "no
scope doc, blocked".

**Why:** My role forbids guessing at intent, and a fabricated requirement traces
to nothing — it creates a test procedure and an implementation task for an
assumption the client never made, which is more expensive to unwind than the
delay. But a blocked handoff that only says "missing input" burns a whole relay
cycle without advancing anything; the SA still has to work out *what* to ask the
client. Pairing the block with the specific unanswered questions means one round
trip instead of two. Happened on issue #1 (2026-08-04), where the kickoff issue
was labeled straight to `agent:systems-engineer` even though its own body said
the Solutions Architect should define scope first — so a misroute, not a real
handoff. Check for the misroute case before assuming upstream work exists.

**How to apply:** Write the conventions-only scaffold (ID scheme, category
blocks, verification/status vocabulary, empty matrix marked "pending") so the
next pass is pure fill-in, put the RFI in `docs/RTVM.md` as a numbered
"Open scope questions" section so it survives the issue thread, then escalate.
Organize questions the way the eventual line items will be organized —
UI / input representation / core algorithm / output representation / output,
plus deliverable requirements and MVP tiering. The MVP-tier question is the one
that unblocks `docs/IMPLEMENTATION_PLAN.md`, so never omit it.
`docs/Workflow.txt` step 2 (5 W's) is a good checklist for finding gaps.

See [[sudoku-solver-project-context]], [[rtvm-conventions]].

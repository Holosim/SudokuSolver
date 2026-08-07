---
name: deliverable-requirements-pattern
description: Named tooling/IDE in a client brief is a deliverable (non-functional) requirement about the artifact, not an incidental build detail — capture it separately from features
metadata:
  type: feedback
---

When a client names an IDE, toolchain, or "I want something my team can extend"
in a brief, capture it as its own **Deliverable requirements** section in
`docs/PROJECT_DEFINITION.md`, separate from the feature/MVP list.

**Why:** nothing in a test-driven RTVM will ever surface these on its own —
there is no runtime behaviour to execute, so they are silently dropped by
omission. On SudokuSolver the client's one-line brief said "built using Visual
Studio 2022 as an IDE"; read literally that is a build detail, but it actually
meant "hand me an openable project my engineers can maintain" (D-1…D-7).

**How to apply:** on kickoff, scan the brief for artifact-shaped wording
(IDE, "my own engineers", "I want to modify this later", language/standard,
"no dependencies"). Write each as a `D-<n>` item with a Source column citing
where it came from, and explicitly notify the Systems Engineer that they need
turning into `docs/SDD.md` build/documentation conventions — they will not
arrive there through the normal requirement flow. See
[[architect-owns-what-not-how]].

---
name: mutation-testing-runtime-logic
description: The mutate-and-rebuild technique from compile-time-invariant-testing also pays off for a brand-new runtime detection pass (e.g. RTVM-104's contradiction scan) — one targeted mutation is enough to prove the tests are falsifiable, not vacuous.
metadata:
  type: feedback
---

[[compile-time-invariant-testing]] established mutate-a-`/tmp`-copy for
`static_assert`/exhaustive-`switch` requirements, where a green build *is*
the assertion. The same cheap check is worth running once for any **brand
new runtime detection pass**, not just compile-time ones — on #10
(2026-08-14), `cp -r` the repo, `if (false && earlierInRow.isApplicable())`
to disable `RowDuplicate` detection in `Parser.cpp`, rebuild the native
suite. 3 of 53 tests failed (`InputFaultTests`, `ParserTests`,
`ReporterTests` — all the ones actually exercising `P-CONTRA-ROW`), the
rest stayed green.

**Why:** a new detection branch landing alongside its own tests is exactly
the case where "the tests pass" could mean either "the logic works" or "the
logic and the tests are both silently doing nothing." One mutation that
kills only the tests that should die (and nothing else) is stronger
evidence than reading the assertions and trusting they're wired to real
code.

**How to apply:** on any issue introducing a new *kind* of fault/result
detection (not a wording change, not a refactor) — one mutation on the
core branch condition, confirm the expected and only the expected tests go
red, then revert. Costs a couple of minutes; don't do it for every
regression pass, same scope limit as `docs/RTVM.md` §9.6 for compile-time
invariants — only when the logic is new.

See [[compile-time-invariant-testing]] and [[cppunittest-shim-gotchas]] for
the harness this runs against.

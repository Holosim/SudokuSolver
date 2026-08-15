---
name: rtvm-004-regression-pass-25
description: Post-merge regression pass on #25 (2026-08-15) confirming the ConPTY harness's first landing on main is clean — Windows evidence reproduces the exact 3-FAIL/5-NOT-RUN signature, Linux substitute counts hold at 67/49.
metadata:
  type: project
---

Regression pass requested by CI/CD in-thread after the ConPTY harness
(`tests/windows/lib/ConPty.ps1`, TP-004/005/006 sections in
`tests/windows/run-procedures.ps1`) reached `main` for the first time via
issue #25's merge (`0892b30`), with CI/CD's own memory-commit push
(`0aaddb1`) and my own RTVM-recording push (`3e23890`) landing right after.
Baseline: `git diff --stat 0892b30 <trunk-tip> -- . ':!.claude/agent-memory'`
— empty outside `docs/RTVM.md` itself (the RTVM-recording commits), no
`src`/`tests/windows` drift. Confirmed with the API compare too
(`compare/0892b30...main`). **Result: PASS, no regression**, at trunk tip
`547a2ee`.

**Windows evidence**: found the run already in-flight for the exact trunk
tip (`31908530006`, headSha match) via `gh run list
--workflow=windows-verification.yml` — polled to completion rather than
triggering a fresh one, per [[windows-evidence-reading]]. Reproduced the
**identical PASS/FAIL signature to the original #25 evidence** (round 11 /
verdict comment): 51 PASS / 3 FAIL / 5 NOT-RUN. The 3 FAILs are always
`TP-006/stop-response-exit-3`, `TP-005/exit-3-within-1s`, `TP-005/
abandonment-message-and-empty-stdout` — same reason text citing
`conpty-diag.txt` probe (6)'s isolated console-input-delivery gap, exit-code
fields genuinely empty (not defaulted-to-pass, checked per
[[false-pass-from-unchecked-exit-codes]]). The 5 NOT-RUN
(`TP-900/901`, `TP-405/aborted-exit-code`, `TP-007/008/507`) match the
pre-#25 8-item NOT-RUN set minus the 3 items #25 now actually attempts
(TP-004/005/006) — arithmetic checks out (8 - 3 = 5).

**Linux substitute**: rebuilt the `/tmp` CppUnitTest shim + generated
driver fresh (no lighter route offered in the hand-off, so full default
per [[trunk-regression-scope]]). Full driver **67/67**, core-only driver
(excludes `MessagesTests.cpp`/`ReporterTests.cpp`, links `src/SudokuCore`
only) **49/49** — both counts match #18's last regression pass exactly,
confirming no test dropped out of the tree since the ConPTY branch (which
touches only `tests/windows/*.ps1`, no `tests/SudokuSolver.Tests/*.cpp`)
merged. Real-binary run against 4 §6.2 fixtures + `malformed.txt`: exit
codes 0/0/0/2/1, all correct.

**RTVM matrix sanity**: `docs/RTVM.md` ends cleanly at §9.35 (4184 lines),
§5 table rows match §9.35's stated outcome exactly (RTVM-004 Verified
`0892b30`; RTVM-005/006/404/501/502 In Test `0892b30`; RTVM-503/RTVM-203
unchanged at their prior SHAs). No merge-conflict damage to check since
CI/CD's RTVM-recording commits were direct-to-main pushes, not merges.

**Hand-off convention confirmed**: per #18's precedent, a regression pass
that reconfirms (rather than newly promotes) still hands off to
`agent:systems-engineer` with `status:ready-for-rtvm-update` — the
"On pass" two-step applies even when the RTVM is already current for the
SHA under test, because the Systems Engineer is the one who records the
reconfirmation and decides whether to close the issue outright (as they
did on #18) rather than route back through CI/CD again.

Related: [[trunk-regression-scope]], [[windows-evidence-reading]],
[[tp004-006-conpty-harness-verified]], [[false-pass-from-unchecked-exit-codes]],
[[generated-test-driver]], [[cppunittest-shim-gotchas]],
[[rtvm-504-regression-pass-19]].

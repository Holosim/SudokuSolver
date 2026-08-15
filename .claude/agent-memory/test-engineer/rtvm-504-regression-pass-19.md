---
name: rtvm-504-regression-pass-19
description: Post-merge regression pass on #19 (2026-08-15) confirming the TP-504 harness's first landing on main is clean — full default suite result, and the exact NOT-RUN signature to expect on future passes until #25 lands.
metadata:
  type: project
---

Regression pass requested by CI/CD (relayed through the Systems Engineer)
after the TP-504 harness (`Invoke-SudokuTimestamped`/`Measure-NeverSilent`
in `tests/windows/lib/Common.ps1`, TP-504 wiring in
`tests/windows/run-timing.ps1`) reached `main` for the first time via
issue #19's merge. Baseline for the diff was the merge commit's non-branch
parent (`71ca759`, the pre-merge trunk tip), not the feature branch's own
tip — `compare/71ca759...main` (6 commits ahead) showed only the harness
files, `docs/RTVM.md`, and agent memory, no `src/` diff, confirming
"harness-only" as claimed. **Result: PASS, no regression**, at trunk tip
`82acc46`.

**No lighter route was offered in the hand-off**, so ran the full default:
Linux substitute (g++ clean build, full driver 66/66, core-only driver
49/49 — exact match to #17's counts) plus the two always-re-run cheap
checks (samples byte-match §6.1 fixtures 5/5, `.sln`/`.vcxproj` not
gitignored), plus real Windows evidence.

**Found the Windows run already in-flight for the exact trunk tip**
(`headSha` match, not just close) via `gh run list
--workflow=windows-verification.yml` — polled to completion instead of
triggering a fresh one, per [[windows-evidence-reading]]'s standing
technique.

**Repeatable NOT-RUN signature as of 2026-08-15** (worth checking future
regression passes against, until #25's ConPTY spike lands): 47/55 PASS,
8/55 NOT-RUN, 0 FAIL. The 8 are always: `TP-900/901` (no VS2022 image on
this runner), `TP-004/005/006/007/008/405(aborted-exit-code)/507` (all
need the interactive prompt/abort protocol driver #25 provides). Same
reason text every time. A regression pass that reproduces this exact
8-item set with identical reasons is itself the "no regression" signal —
don't just eyeball the aggregate 47/55, name the 8 and compare.

TP-504's own rows were cross-checked against `timing-sample-*.json`'s
`exitCode` field per sample (0/0/2/1 for easy/hard17/unsolvable/badchar),
not just the `[PASS]` text — see [[false-pass-from-unchecked-exit-codes]].
Long-solve hook: first byte ~15.0–15.04 s, max gap ~10.01–10.02 s,
`timedOut=true` at the 60 s window, consistent across all 3 W-7 samples
and consistent with the original #19 evidence in [[rtvm-504-verified]].

Related: [[trunk-regression-scope]], [[windows-evidence-reading]],
[[rtvm-504-verified]], [[generated-test-driver]],
[[false-pass-from-unchecked-exit-codes]].

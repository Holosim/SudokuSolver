---
name: windows-evidence-reading
description: How to reach and read windows-verification.yml evidence from an Ubuntu agent run, the three surfaces that misreport a failed step as green, and what the artifact does and doesn't prove
metadata:
  type: project
---

Windows verification runs as a separate `windows-verification.yml` on
`windows-latest`, push-triggered on `main` and `issue-*`. It publishes
evidence and never issues a verdict (W-2) — **the verdict is mine**.

**Reaching it from Ubuntu** (all within `actions: read`, no permission
issues):

```
gh run list --workflow=windows-verification.yml --limit 10
gh run view <id> --json status,conclusion,headSha
gh run download <id> -D /tmp/ev        # must be run from inside the repo
gh run view <id> --log | grep -F "TP-905"
```

**Never trust a green tick, and — measured 2026-08-13 — never trust the
step conclusion either.** Three surfaces lie in the same direction:

1. `continue-on-error: true` sets a failed step's **conclusion** to
   `success` while its *outcome* is failure. `gh api .../jobs` and the
   run UI both show green for a step that errored and produced nothing.
2. The summary table keys rows on "did an output file appear", so a step
   that ran and errored renders identically to one never attempted
   (`NOT-RUN`) — defect DW-2.
3. The job as a whole concludes `success` with failed steps inside it.

Only the raw log and its `##[error]` annotation tell the truth. Read the
log for every procedure I intend to rule on. Confirmed a second time on
#9's regression pass (run `31726188002`, trunk `d7d5e69`): every step
reported `success`, and TP-905 had failed inside it.

**`concurrency: cancel-in-progress: true` is keyed on the ref**, so a
rapid second push to `main` cancels the first run. Three of six `main`
runs on 2026-08-13 were cancelled this way, including the `issue-9`
merge commit's. Before ruling on a merge, check that evidence exists for
*that* SHA — or diff the product tree against the SHA that does have
evidence (`git diff --stat <merge> <evidenced> -- src tests *.sln
samples`; empty means the evidence covers it). **Better: look for a run
on the trunk tip I am actually testing.** On #9's regression the tip
`d7d5e69` had its own uncancelled run, which is stronger than the
`42c3625` run the hand-off named — a hand-off names the newest run at
*writing* time, not at testing time, the same trap as
[[trunk-regression-scope]]'s stale file list.

Machine facts (CPU, clock, image) change between runs on the same day —
EPYC 9V74 / 2596 MHz and EPYC 7763 / 2445 MHz hours apart. Always quote
`evidence/machine.md` from the same run (W-9).

**What the artifact proves today, split carefully** (as of 2026-08-13):

- **Compilation of the shipping `_WIN32` code is executed evidence.**
  `build-debug.log` / `build-release.log` show `Build succeeded, 0
  Warning(s), 0 Error(s)` under MSVC 14.44.35207 / `v143` /
  `/std:c++17 /permissive- /W4`. Grep the log for the specific source
  file to state that a particular platform branch compiled —
  `StdinChannel.cpp` appears in both compile lines. This retires the
  "inspected, not compiled" caveat on Windows-only code, and nothing
  more.
- **Execution is not.** TP-905 has never produced a result: DW-1 means
  `vstest.console.exe` exits 1 on the malformed `/ListTests:` argument,
  so no `discovered-tests.txt` and no `.trx` exist at any commit. V-1's
  discovery clause stays open.
- `runtime-procedures.txt` / `timing.txt` read *"not present - NOT-RUN"*
  while `tests/windows/run-procedures.ps1` and `run-timing.ps1` are
  absent. That is V-6-correct behaviour, not a pass and not a
  regression.
- TP-506's automatable clause does run: `dumpbin-dependents.txt` should
  show `KERNEL32.dll` and nothing else (no `MSVCP140.dll`,
  no `VCRUNTIME140*.dll`) — the `/MT` static-CRT claim, checkable in one
  grep.

Report the compile/execute split explicitly and leave the crediting to
the Systems Engineer; measuring is mine, writing the RTVM row is not.

**DW-1 is now fixed (issue #23/#24, 2026-08-14) — the execute half is no
longer permanently unavailable.** `tests/windows/run-procedures.ps1` now
invokes `vstest.console.exe` correctly (separate discovery and execution
calls; the workflow's own inline "TP-905" step is still the broken
`/ListTests:<output-path>` form and still fails — that's expected and
irrelevant, everything reads the script). On #10's V-1/DW-1 regression
pass (run `31797295886` @ `4d80c8c`), `discovered-tests.txt` +
`tests.trx` gave genuine per-method Passed/Failed for all 53 methods,
letting me grep for the specific 28 methods a given RTVM row owns and
confirm each one's `outcome="Passed"` directly from the trx rather than
trusting the script's own PASS/FAIL summary line. **Do this per-row
cross-check whenever a hand-off says a specific row's V-1/DW-1 clause is
what's outstanding** — the aggregate 53/53 doesn't by itself prove any
one row's methods are in that count, only that discovery/execution work
at all.

**Also check `runs/<label>/{stdout,stderr}.txt` against
`runtime-procedures.json`'s per-case `observed` field, not just the
`[PASS]`/`[FAIL]` text summary** — the json carries the actual
`exit=N stdoutBytes=… stderrBytes=…` string the PASS was computed from,
which is what lets you confirm the check was exit-code-gated rather than
timing/content-only (see [[false-pass-from-unchecked-exit-codes]]).

**A Windows run already in flight for the exact trunk SHA under test is
fair game — no need to trigger a fresh one.** `gh run list
--workflow=windows-verification.yml` occasionally shows an `in_progress`
run whose `headSha` already matches; polling it to completion
(`gh run view <id> --json status -q .status` in a wait loop) is cheaper
and no less valid than starting a new one.

See [[no-windows-runner]] for what the Ubuntu substitute toolchain can
and cannot prove, and [[test-engineer-cannot-author-repo-files]] for who
writes the procedure scripts.

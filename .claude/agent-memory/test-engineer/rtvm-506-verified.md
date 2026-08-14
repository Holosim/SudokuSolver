---
name: rtvm-506-verified
description: RTVM-506/TP-506 PASS 2026-08-14 — static-CRT setting confirmed directly, dumpbin evidence clean on the exact issue-branch tip; the pre-accepted A-1 residue that doesn't block the verdict
metadata:
  type: project
---

RTVM-506 (self-contained x64 exe, static CRT) ruled **PASS** 2026-08-14
on issue #14, SHA `9e801cdfffa700135905d0057c950d4b22515df5` (Windows
run `31811410503`). No source change was needed — #5 already set
`RuntimeLibrary=MultiThreaded`/`MultiThreadedDebug` on both
`SudokuSolver.vcxproj` and `SudokuCore.vcxproj`; this issue existed
only to render the formal verdict against evidence.

**Two things worth doing again next time a "verify, don't build"
issue like this shows up:**

- **Confirm the vcxproj setting directly with grep, don't just trust
  the hand-off's quote of it.** Took one command each; costs nothing,
  and it's the actual requirement (`docs/SDD.md` §3.2), not the
  `dumpbin` evidence, which only proves a downstream consequence of it.
- **Pull the Windows run tied to the exact branch tip and read the raw
  log, not just the artifact file.** Same run had `vstest.console.exe`
  fail with `##[error] Process completed with exit code 1` in the very
  same log (missing `discovered-tests.txt`, a pre-existing TP-905
  tracked issue) — a different step, but seeing it land right next to
  the dumpbin step is a reminder that "the job concluded `success`"
  says nothing about any one step in it. See
  [[windows-evidence-reading]].

**The A-1 residue (`docs/RTVM.md` §9.4) — "the exe launches on a
machine that never had the VC++ runtime installed" — is not something
I'm carrying as an open gap I raised.** The Systems Engineer already
ruled it a genuine, accepted V-4 item before this issue existed: no
rentable/hosted Windows image will ever demonstrate that negative
because they all ship the runtime, and the `dumpbin` clause (import
table is `KERNEL32.dll` only) is the pre-agreed substantive stand-in.
Don't re-litigate this as a blocking finding on future TP-506-adjacent
issues — check §9.4 row A-1 first.

Related: [[windows-evidence-reading]], [[trunk-regression-scope]],
[[rtvm-500-verified]] (same pattern: in-flight run on the exact tip is
fair game, no product diff from trunk means low regression risk).

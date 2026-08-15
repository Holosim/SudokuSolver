---
name: rtvm-504-verified
description: RTVM-504 (never-silent piecewise 16.0s/11.0s bound) passed 2026-08-15 on real Windows evidence; the mutation trick used to prove the new TP-504 checks aren't vacuous, and a Linux-only flaky launch error to not mistake for a regression.
metadata:
  type: project
---

RTVM-504 is **verified**, ruled 2026-08-15 on issue #19, branch tip
`d4d79b2` (Windows run `31863267320`, `win25-vs2026`, headSha match, no
`##[error]` in the timing step). All three W-7 samples: TP-504's five
cases (`P-EASY`, `P-HARD17`, `P-UNSOLVABLE`, `P-BADCHAR`, long-solve hook)
all PASS, first byte 22-74ms for the four ordinary fixtures and
~15.0-15.05s for the long-solve hook, max gap ~9.99-10.02s — both well
inside the 16.0s/11.0s ceilings, exit codes correct (0/0/2/1) so the PASS
is exit-code-gated, not just timing-shaped (see
[[false-pass-from-unchecked-exit-codes]]). Zero `[FAIL]` rows anywhere in
`timing.txt` or `runtime-procedures.txt`; 66/66 unit tests Passed in
`tests.trx`. No product source touched by this issue at all
(`git diff --stat` over `src/` across every commit on the branch is
empty) — confirms the Software Engineer's claim that #17's prompt
cadence already covered the behaviour and this issue was harness-only.

**New verification technique worth reusing**: mutation-tested the harness
itself, not just the product. Copied `run-timing.ps1`, dropped
`$FirstByteCeilingMs`/`$GapCeilingMs` to `1.0`, reran against the same
Linux g++ build — all five TP-504 rows flipped to `FAIL` with the correct
reason text (`first byte at ...ms exceeds the 1ms ceiling`). This is the
same discipline as [[mutation-testing-runtime-logic]] applied to a test
*script* rather than product logic: a check that only ever reports PASS
is unfalsifiable evidence, and the SE's own five-fixture PASS run alone
doesn't rule that out. Restore the original file and confirm
`git status`/`git diff --stat` are clean afterward — don't leave the
mutant in the tree.

**Flaky-on-Linux-only, not a regression**: the first "easy" run in a
fresh `Invoke-Sudoku`-driven TP-500 loop occasionally exits `-1` with
`LaunchError: Broken pipe` on this Ubuntu runner (seen once in two
back-to-back runs of the same unmodified binary). Re-running is clean.
Confirmed absent from the real Windows evidence (0 FAIL rows across all
3 samples) and unrelated to this issue's new `Invoke-SudokuTimestamped`
path (TP-504's own four ordinary-fixture rows never hit it, same run).
Treat a single first-iteration `Broken pipe`/exit `-1` on the Linux
substitute build as a runner artifact worth a re-run before treating it
as a real defect — but still cross-check the exit code every time per
[[false-pass-from-unchecked-exit-codes]], since this is exactly the shape
of bug that memory warns about, just not this particular occurrence.

Related: [[no-windows-runner]], [[windows-evidence-reading]],
[[mutation-testing-runtime-logic]], [[false-pass-from-unchecked-exit-codes]].

---
name: tp004-006-conpty-harness-verified
description: 2026-08-15 verification of issue #25's ConPTY harness for TP-004/005/006 (RTVM §9.4 A-4) — a genuine automated Windows console-handle driver, plus a real (not harness-bug) infra-level gap for console input delivery on the hosted runner image
metadata:
  type: project
---

Confirmed on issue #25 (2026-08-15), run
[31903980994](https://github.com/Holosim/SudokuSolver/actions/runs/31903980994),
`windows-latest`, headSha `cf67e0d`. This closes the long-standing A-4 gap
noted in [[rtvm004-prompt-abort-verified]] ("Console/tty `StdinKind` branch
remains untested by any harness") — there is now a real automated driver,
not just hand-run evidence.

**What it is:** `tests/windows/lib/ConPty.ps1`, a genuine
`CreatePseudoConsole`-based driver (real ConPTY, `CreateProcessW` under
`EXTENDED_STARTUPINFO_PRESENT`, raw `ReadFile`/`WriteFile` on the pty
pipes). `run-procedures.ps1`'s new `TP-004,TP-006` and `TP-005` sections
drive `SudokuSolver.exe` under it.

**Result, reproduced independently (not just re-reading the SE's summary):**
- TP-004 — genuine PASS both clauses. Raw `stderr.txt` under
  `runs/TP-004-006-conpty/` shows the exact prompt wording from
  `docs/RTVM.md`'s TP-004 reference text; `stdout.txt` stays 0 bytes.
- TP-006 — PASS on cadence (4+ prompts, no >11s gap) and still-running;
  **FAIL on stop-response-exit-3**. Raw stderr shows a 5th prompt at 55s,
  which is only possible if the stop response never landed.
- TP-005 — FAIL both clauses. Raw stderr for the dedicated session shows
  exactly one prompt line and no "abandoned at" text ever appears.

**Root cause, isolated not assumed:** `conpty-diag.txt` probe (6) — true
direct attachment, no `cmd.exe`, no redirect wrapper, result reported via
a file write from *inside* the child so a render-pass failure can't hide
a real event. `writeInputOk=True` (host `WriteFile` succeeds) but
`GetNumberOfConsoleInputEvents` stays 0 and `ReadConsoleA` never
unblocks — bytes written to the ConPTY input pipe never surface as a
console input event **on this hosted runner image**, independent of
process shape (`cmd.exe`/PowerShell/direct) or encoding. This is upstream
of `StdinChannel.cpp`/`SolveSession.cpp` entirely — the product's
`Console` `StdinKind` branch is never reached because the console handle
never receives the write. **Not a product defect and not a harness bug**
(three independently-tightened probes agree) — a platform/image
limitation. Re-check if the runner image ever changes (self-hosted
runner, different `windows-latest` generation, etc.) since this is
exactly the kind of thing that could silently start working.

**Verification technique worth reusing:** read the raw per-run
`stdout.txt`/`stderr.txt` under `evidence/runs/<label>/`, not just the
`runtime-procedures.json` `observed` string — counting prompt lines
directly in the raw file is a stronger independent check than trusting
the harness's own `PromptTimestampsSec` array, and confirmed the
`promptsAfterStopAttempt=1` field's story matched what's actually in the
stream.

Also confirmed (per [[trunk-regression-scope]]) that this branch touches
`tests/windows/lib/ConPty.ps1` and `run-procedures.ps1` only — no `src`
diff at all, so no product regression surface to separately re-check
beyond the build+TP-905 unit run already in the same artifact.

See also [[false-pass-from-unchecked-exit-codes]] (the exit-code-gating
check applied here), [[windows-evidence-reading]].

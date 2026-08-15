---
name: rtvm004-prompt-abort-verified
description: 2026-08-14 PASS on issue #17 (RTVM-004/005/006/007/008/404/501/502/503) — how to hand-run the RTVM-507 hook's interactive prompt/abort protocol on Linux with real timestamps, and the post-#24 rule about hand-run evidence never reaching Verified by itself.
metadata:
  type: project
---

Verified on issue #17 (2026-08-14), trunk tip `091e914`. All nine line items
this issue owns PASSED — see the issue comment for full numbers. Notable
technique and policy points worth reusing:

**Timestamped stderr-line technique (better than eyeballing `cat -n`
output).** Pipe the child's stderr through a `while IFS= read -r line; do
NOW=$(date +%s.%N); ...; done` loop and compute `NOW - START` per line. Gave
prompt timestamps accurate to ~10ms against a `SUDOKU_DIAG_MIN_SOLVE_MS`
run — far tighter than the ±1.0s tolerance RTVM-501/502 ask for, and turns
"prompts appeared roughly on schedule" into an actual number per prompt.
Confirms the SE's "anchored to the fixed schedule, not to when the poll
happened to notice" design claim directly: five prompts all landing within
~9ms of nominal, not drifting cumulatively.

**Named pipe (`mkfifo`) is the right tool for the control channel on
Linux**, for two different shapes:
- Send-after-delay: `exec 3>/tmp/pipe` in the foreground shell, `sleep N;
  echo s >&3` — gives a real abort-latency measurement (`date +%s.%N`
  around the write and the `wait`).
- Held-open-never-written: `exec 4<>/tmp/pipe` (open for read+write so it
  doesn't hit EOF), confirms the process survives past several prompt
  windows and never blocks on the read (RTVM-006/RTVM-008's "no response
  required" property is actually exercised, not just asserted).

**Single-owner-buffer edge case is worth checking explicitly, not just
trusting the SDD §1.3 I-17 description**: write a puzzle file with a
trailing `stop` line already present, run with the file as stdin and no
prior prompt — the stop is picked up on the very first poll (~10ms), well
before the 15s threshold. This is what actually falsifies "RTVM-005 is
gated on a prompt having fired first," which isn't obvious from reading the
SolveSession.cpp diff alone.

**Post-#24 policy point (docs/RTVM.md §9.8.1, following from #24's
ProcessRunner harness landing):** once an automated Windows harness exists
for a given TP family, hand-run evidence — mine or the Software Engineer's
— can no longer be cited as *itself* moving a UI/OUT row to Verified, even
if every clause passes. `run-procedures.ps1` reported TP-004…008 and
TP-507's active-demonstration clause `NOT-RUN` on this exact SHA with the
same "5s probe ceiling, no interactive-protocol driver" reason recorded on
#16 — expected, not a regression, and not something my hand-run testing can
paper over. Flag this explicitly in the PASS comment so the Systems
Engineer promotes to the right rung (In Test, most likely, matching how
RTVM-001/002/003 sat at In Test through #24 despite full automated
evidence) rather than skipping straight to Verified on my say-so.

**Console/tty `StdinKind` branch remains untested by any harness in this
pipeline** — no pty on the Linux runner, and `run-procedures.ps1` doesn't
drive one either yet. This is the pre-existing A-4/ConPTY item, not
something #17 introduced or was scoped to close. Keep citing it as a
standing gap on future issues that touch `StdinChannel.cpp`'s Console case,
rather than re-discovering it each time.

See also [[rtvm-507-diagnostic-hook-verification]], [[windows-evidence-reading]],
[[false-pass-from-unchecked-exit-codes]] (checked exit codes on every hand-run
case here too).

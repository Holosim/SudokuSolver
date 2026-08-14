---
name: rtvm-507-diagnostic-hook-verification
description: How to verify the SUDOKU_DIAG_MIN_SOLVE_MS long-solve hook (RTVM-507) is genuine work and not a sleep, fully on the Linux runner — no Windows needed for this one.
metadata:
  type: project
---

RTVM-507 (`docs/SDD.md` §3.6) is unusual among the RTVM-5xx timing items: its
mechanism (env var read via `getenv`/`strtol`, `std::chrono::steady_clock`
busy-loop) is portable C++ with no Windows-specific surface, so — unlike
[[no-windows-runner]]'s usual caveat — **TP-507 is fully runnable on the
Linux agent, not just inspectable.** Confirmed 2026-08-14 on issue #13.

**The key check that distinguishes "real work" from "sleep in disguise":**
run the built binary under `/usr/bin/time -v` with the hook active and
compare *user CPU time* to *wall clock time*. A real repeating search
(`SUDOKU_DIAG_MIN_SOLVE_MS=3000`) produced 3.00s user time against 3.002s
wall time — CPU-bound, 1:1. A `sleep`-based fake would show near-zero user
time against the same wall time. Cheap, decisive, no need to instrument the
binary.

**Other checks worth the few minutes they take:**
- Byte-diff stdout between the inert run and the active run — the hook must
  never change the *answer*, only how long producing it takes.
- Drive every inert variant (unset / empty / `"0"` / negative / non-numeric
  / trailing-garbage / whitespace-only) through the real binary, not just
  the unit tests — confirms the console-layer `strtol` parsing end to end,
  which the unit tests alone don't touch since they set `SolveOptions`
  directly rather than going through `main.cpp`.
- `grep -rn getenv src/` — confirms the RTVM-903 core/console split holds
  for this specific hook (the core must never call `getenv` itself).
- TP-507 explicitly asks for a >60s demonstration; a straight
  `SUDOKU_DIAG_MIN_SOLVE_MS=61000` run finishes on its own in ~61s wall
  clock on this runner — no need to background it or raise the Bash
  timeout, it fits inside the default 120s budget.

**How to apply:** any future issue touching this hook (e.g. if #16 wires
RTVM-203/204's timing procedures through it) — reuse this CPU-time check
before trusting a "genuine work, not a sleep" claim in a handoff.

**The Windows harness's own runtime-procedures script already detects the
hook going active, but can't finish TP-004–008/TP-507's active-demonstration
clauses yet.** On #13's post-merge regression (2026-08-14, trunk `a1c7bc3`),
`runtime-procedures.json`/`.txt` set `SUDOKU_DIAG_MIN_SOLVE_MS=20000` and
reported `NOT-RUN` with reason *"process still running after the 5s probe
ceiling; hook appears active but this script does not yet drive its
interactive prompt/abort protocol"* for TP-004/005/006/007/008 and TP-507's
own active-hook-demonstration case. That is expected, current state — not a
regression, and not new information — because the script only has a
process-alive probe, not the stop-response protocol TP-004–008 need. Don't
re-report it as a defect on a future regression pass; just confirm the
reason text is still this one (a different reason would be worth flagging).
The 60s+ demonstration and TP-501–504 remain out of *this* hook's scope —
see the RTVM-507 row's own §9.19 note (issue #16 territory).

---
name: blocking-is-allowed-before-the-solve
description: RTVM-006/008 forbid blocking in the prompt mechanism, not in the pre-solve puzzle read — the reading behind StdinChannel::readLineBlocking
metadata:
  type: project
---

`StdinChannel` has two reads and the distinction is load-bearing:
`readLineBlocking` waits, `tryReadLine` never does. Reading a puzzle a user is
still typing cannot be done without waiting, so RTVM-003 is unimplementable
under a literal "never block anywhere" rule.

**Why:** RTVM-006 is about *prompts* ("no prompt requires a response") and
RTVM-008 about the *prompt mechanism* never delaying a redirected run.
`docs/SDD.md` §3.7 states the ban more absolutely — "what is **not** acceptable
under any circumstance is any call that can block" — written in the context of
the console availability probe. Taken literally the two conflict. Implemented
on the narrow reading (the ban binds the solve path) and flagged to the Systems
Engineer on issue #9, 2026-08-13; no ruling yet.

**How to apply:**
- Anything reachable from inside `solve()` uses `tryReadLine` and nothing else.
  Issue #17 owns making that one genuinely non-blocking with the §1.3
  availability tests.
- Call `readLineBlocking` only before the solve starts. It is a bounded read:
  the caller passes a byte cap and gets a truncated line rather than an
  unbounded buffer, which is how `docs/RTVM.md` §7 I-13 is honoured on the
  stdin path.
- If the ruling goes the other way, the fix is a poll loop over `tryReadLine`
  during puzzle acquisition — the buffer ownership does not change.

Related: [[console-layer-platform-seam]], [[parser-precedence-reading]]

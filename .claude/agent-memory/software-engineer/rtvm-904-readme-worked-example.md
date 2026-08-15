---
name: rtvm-904-readme-worked-example
description: Filling in the README (RTVM-901/904/905/907) — get the worked example output from a real build, not by transcribing §6.2
metadata:
  type: project
---

Issue #22 filled in the README skeleton from #5 against `docs/SDD.md` §3.4.
The seven required sections are literal and TP-904/TP-901 are Inspection
procedures against the file, so there's no ambiguity in what's required —
but two things are worth remembering for the next doc-only issue like this:

1. **Build the g++ proxy even for a docs-only issue** ([[no-msvc-in-agent-runner]])
   and run it against the actual `samples/*.txt` to get the README's "Run"
   worked-example output, rather than copying §6.2's `S-EASY` block. They
   happen to match here, but the README should reflect what the shipped
   binary actually prints, and running it once is cheap insurance against a
   stale fixture.
2. **The "no mention of RTVM-507" exclusion is a real trap for this kind of
   issue** — §3.4 and the issue body both call it out explicitly because a
   generic "how do I make this run longer for testing" instinct while
   writing the Run/Samples sections would leak `SUDOKU_DIAG_MIN_SOLVE_MS`
   into the one place it's forbidden (TP-507 inspects for its *absence*
   here and *presence* only in `docs/SDD.md` §3.6). Checked the diff for
   the literal string before handing off.

No product code changed in this issue — only `README.md`. The g++ build
was rebuilt from unmodified sources purely to capture real output text.

Related: [[no-msvc-in-agent-runner]], [[output-layer-scope-per-issue]].

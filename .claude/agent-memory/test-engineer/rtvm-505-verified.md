---
name: rtvm-505-verified
description: RTVM-505 (adversarial-input robustness corpus) PASS on issue #20, 2026-08-15 — last NFR in the plan, real vstest/TP-505 evidence with exit-code-gated data, and the file-argument-vs-stdin nuance in the corpus.
metadata:
  type: project
---

2026-08-15, issue #20, branch `issue-20` @ `662b6ed`: **PASS**. No product
code change (Software Engineer's finding, confirmed) — RTVM-505 is a
property earlier issues already had to establish (bounded reads, I-13;
byte-oriented parsing; `main`'s catch-all mapping faults to exit `1`).

**Real Windows evidence, not just the script's own summary.** Windows run
`31866470868` was already in-flight for this exact branch tip when checked
(per [[windows-evidence-reading]]'s "in-flight run is fair game" note) —
polled to completion rather than triggering a fresh one. `runs/TP-505/`
has 27 case directories (8 hand-built edge cases + 17 §6.1 fixtures +
directory-argument + locked-file-argument), all PASS, exit codes observed
∈ {0,1,2} (3 never exercised here — RTVM-507's abort hook isn't wired to
this script yet, expected, see below). Cross-checked
`runtime-procedures.json`'s per-case `observed` field
(`exit=N timedOut=False elapsedMs=… crashText=False`) rather than trusting
the `[PASS]` text alone, per [[false-pass-from-unchecked-exit-codes]]. The
aggregate `TP-405 / corpus-exit-code-range` check also PASSed (distinct
codes 0,1,2 across all 27 entries).

**`P-BLANK` confirmed non-hanging**: exit `0`, ~6.7 ms, genuine
`SolvedNotUnique` grid + note in stdout — the RTVM-202 `maxSolutions=2`
cap finding its second solution instantly, exactly as the issue's design
pointers claimed.

**Corpus nuance worth remembering**: the script passes *every* entry's
path as a file argument (`Invoke-Sudoku -ArgList @($entry.Path)`), never
via stdin. So `empty-input-zero-bytes` *is* the "zero-byte file argument"
case the issue text asks for by a different name — there's no separate
stdin-empty case and none is needed. Don't flag its absence as a gap.

**Regression check reproduced the exact known-good signature** from
[[rtvm-504-regression-pass-19]]: 47/55 PASS, 8/55 NOT-RUN (same 8 items,
identical reason text: `TP-900/901` no VS2022 image, `TP-004/005/006/
007/008/405(aborted)/507` all needing the still-unwired interactive
prompt/abort driver), 0 FAIL. Unit driver 67/67 (`tests.trx`), matching
[[rtvm-405-406-verified]]'s count. The `TP-905` inline workflow step's
`##[error]` is the known-standing masked failure (workflow's own
`/ListTests:` form, not the script's) — irrelevant here, everything reads
`run-procedures.ps1`'s own evidence per [[windows-evidence-reading]].

**Linux substitute**: g++ `-std=c++17 -O2 -DNDEBUG -Wall -Wextra` clean
build, 0 warnings; hand-ran empty/newline/embedded-NUL/directory-argument
locally and got matching exit=1 + sane stderr text — same shape as the
Windows evidence, independent of it.

This closes the RTVM plan's last NFR (priority 16). RTVM-505 was still
`Approved` at hand-off, per the standing convention that the Systems
Engineer promotes the row, not the Software Engineer's commit — see
[[rtvm-500-verified]] and siblings.

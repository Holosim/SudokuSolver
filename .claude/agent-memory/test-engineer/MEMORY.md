# Test Engineer — memory

## Test harness notes

- [No Windows runner](no-windows-runner.md) — agent runs are Ubuntu with no MSVC/VS; what can substitute (g++ cross-compile, `/tmp` CppUnitTest shim) and what it proves.
- [CppUnitTest shim gotchas](cppunittest-shim-gotchas.md) — namespace qualification and the extra macros the `/tmp` shim needs; both look like product defects and aren't.

- [Generated test driver](generated-test-driver.md) — scan `TEST_CLASS`/`TEST_METHOD` to build the driver; the discovered count is the regression signal, plus the `.vcxproj` registration check it can't replace.

- [Compile-time invariant testing](compile-time-invariant-testing.md) — `static_assert`/`-Wswitch` "tests" prove nothing unless mutated; how, plus the private-ctor false negative.
- [Mutation testing runtime logic](mutation-testing-runtime-logic.md) — the same mutate-and-rebuild trick, applied once per brand-new detection pass (e.g. RTVM-104) to prove its tests aren't vacuous.

- [Reading Windows evidence](windows-evidence-reading.md) — reaching `windows-verification` artifacts from Ubuntu, the three surfaces that render a failed step green, and the compile-vs-execute split.

## How to scope work

- [I don't author repo files](test-engineer-cannot-author-repo-files.md) — the write guard covers test-harness scripts too; spec them and hand to Software Engineer.

- [Trunk regression scope](trunk-regression-scope.md) — diff product content against the passed branch tip first; what to re-run regardless; don't re-litigate Verified items.
- [Doc drift is not a failure](doc-drift-is-not-a-failure.md) — stale source comments contradicting a new §7 ruling go to the Systems Engineer as an observation, not a handback.

## Platform-specific test considerations

- [DELIV inspection coverage](deliv-inspection-coverage.md) — which of TP-900..907 fully execute here, which need Windows, and the extra load-failure checks worth running.
- [Parser test scope + I-15 ruling](parser-test-scope-and-open-ruling.md) — TP-101/106 half-runnable until #8/#9; whitespace-precedence now settled as IllegalCharacter.
- [Solver coverage limits](solver-coverage-limits.md) — TP-200's fixtures never reach the DFS; mutants it can't see, and the randomised-oracle cross-check that covers it.
- [Console layer runs end-to-end now](console-layer-end-to-end-now-runnable.md) — since #9 the whole binary builds on Linux; how to byte-compare §6.2 stdout without hiding the final newline.
- [TP-202 non-uniqueness + P-BLANK substitution](tp202-nonuniqueness-and-p-blank-substitution.md) — independently reproduced the SE's node-count claim on #12; how to byte-check TP-401 end to end.

## How to scope work (cont.)

- [Systems Engineer piggyback obligations](systems-engineer-piggyback-obligations.md) — an in-thread comment (not the issue body) can attach an extra RTVM item to an issue by file-touch timing; check the whole thread before sign-off.

## Verified requirements (context worth keeping)

- [RTVM-500 verified](rtvm-500-verified.md) — 2026-08-14 PASS with real exit-code-gated timing data; why TP-501-504 staying open doesn't block it, and to re-check inertness once #13 wires up the RTVM-507 hook.
- [RTVM-506 verified](rtvm-506-verified.md) — 2026-08-14 PASS; static-CRT confirmed by direct grep + clean dumpbin on the exact branch tip; the A-1 clean-machine residue is pre-accepted, not a fresh gap.
- [RTVM-507 diagnostic hook verification](rtvm-507-diagnostic-hook-verification.md) — 2026-08-14 PASS, fully runnable on Linux (no Windows needed); the CPU-time-vs-wall-time trick that proves it's real work, not a sleep.
- [RTVM-203/204 verified](rtvm-203-204-verified.md) — 2026-08-14 PASS; first RTVM-2xx item with real MSVC/vstest trx confirming literal TP timing numbers; branch-ancestry vs. issue-number-order gotcha for the DW-1 fix.
- [RTVM-004 prompt/abort verified](rtvm004-prompt-abort-verified.md) — 2026-08-14 PASS; timestamped-stderr and named-pipe hand-run technique; post-#24 rule that hand-run evidence alone can't reach Verified once an automated harness exists.
- [RTVM-504 verified](rtvm-504-verified.md) — 2026-08-15 PASS on real Windows evidence; mutating the harness's own ceiling constants to prove TP-504's checks aren't vacuous; a Linux-only flaky launch error that isn't a regression.

## Recurring failure patterns

- [Stub wording vs exit codes](stub-wording-vs-exit-codes.md) — right exit code with an empty stream is expected state on this project, not a defect; which issue owns which wording.
- [False PASS from unchecked exit codes](false-pass-from-unchecked-exit-codes.md) — a timing/content check that never looks at the child's exit code can PASS on a run that never executed; always cross-check the exit code, and check whether a captured error field actually reached the artifact.

<!-- Bugs or regressions that have shown up more than once, and what
     actually fixed them, so they're recognized faster next time. -->

## Flaky tests

<!-- Tests known to fail intermittently for reasons unrelated to the
     code under test, and the current best guess why. -->

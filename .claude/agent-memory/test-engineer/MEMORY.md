# Test Engineer — memory

## Test harness notes

- [No Windows runner](no-windows-runner.md) — agent runs are Ubuntu with no MSVC/VS; what can substitute (g++ cross-compile, `/tmp` CppUnitTest shim) and what it proves.
- [CppUnitTest shim gotchas](cppunittest-shim-gotchas.md) — namespace qualification and the extra macros the `/tmp` shim needs; both look like product defects and aren't.

- [Generated test driver](generated-test-driver.md) — scan `TEST_CLASS`/`TEST_METHOD` to build the driver; the discovered count is the regression signal, plus the `.vcxproj` registration check it can't replace.

- [Compile-time invariant testing](compile-time-invariant-testing.md) — `static_assert`/`-Wswitch` "tests" prove nothing unless mutated; how, plus the private-ctor false negative.

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

## Recurring failure patterns

- [Stub wording vs exit codes](stub-wording-vs-exit-codes.md) — right exit code with an empty stream is expected state on this project, not a defect; which issue owns which wording.
- [False PASS from unchecked exit codes](false-pass-from-unchecked-exit-codes.md) — a timing/content check that never looks at the child's exit code can PASS on a run that never executed; always cross-check the exit code, and check whether a captured error field actually reached the artifact.

<!-- Bugs or regressions that have shown up more than once, and what
     actually fixed them, so they're recognized faster next time. -->

## Flaky tests

<!-- Tests known to fail intermittently for reasons unrelated to the
     code under test, and the current best guess why. -->

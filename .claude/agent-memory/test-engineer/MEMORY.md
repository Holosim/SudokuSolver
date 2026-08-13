# Test Engineer — memory

## Test harness notes

- [No Windows runner](no-windows-runner.md) — agent runs are Ubuntu with no MSVC/VS; what can substitute (g++ cross-compile, `/tmp` CppUnitTest shim) and what it proves.
- [CppUnitTest shim gotchas](cppunittest-shim-gotchas.md) — namespace qualification and the extra macros the `/tmp` shim needs; both look like product defects and aren't.

## How to scope work

- [Trunk regression scope](trunk-regression-scope.md) — diff product content against the passed branch tip first; what to re-run regardless; don't re-litigate Verified items.

## Platform-specific test considerations

- [DELIV inspection coverage](deliv-inspection-coverage.md) — which of TP-900..907 fully execute here, which need Windows, and the extra load-failure checks worth running.
- [Parser test scope + I-15 ruling](parser-test-scope-and-open-ruling.md) — TP-101/106 half-runnable until #8/#9; whitespace-precedence now settled as IllegalCharacter.

## Recurring failure patterns

<!-- Bugs or regressions that have shown up more than once, and what
     actually fixed them, so they're recognized faster next time. -->

## Flaky tests

<!-- Tests known to fail intermittently for reasons unrelated to the
     code under test, and the current best guess why. -->

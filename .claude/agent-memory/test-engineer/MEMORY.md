# Test Engineer — memory

## Test harness notes

- [No Windows runner](no-windows-runner.md) — agent runs are Ubuntu with no MSVC/VS; what can substitute (g++ cross-compile, `/tmp` CppUnitTest shim) and what it proves.

## Platform-specific test considerations

- [DELIV inspection coverage](deliv-inspection-coverage.md) — which of TP-900..907 fully execute here, which need Windows, and the extra load-failure checks worth running.

## Recurring failure patterns

<!-- Bugs or regressions that have shown up more than once, and what
     actually fixed them, so they're recognized faster next time. -->

## Flaky tests

<!-- Tests known to fail intermittently for reasons unrelated to the
     code under test, and the current best guess why. -->

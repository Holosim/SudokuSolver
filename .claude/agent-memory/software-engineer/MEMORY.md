# Software Engineer — memory

## Architecture patterns

- [SudokuSolver module layout](sudoku-module-layout.md) — the scaffold decisions that `DELIV` inspections read; don't undo them casually.

## Platform-specific notes

- [No MSVC in the agent runner](no-msvc-in-agent-runner.md) — runs are Linux/g++; how to compile-check a VS 2022 deliverable anyway.
- [CppUnitTestFramework and the static CRT](msvc-cppunittest-crt.md) — why a `/MT` exe forces the test project to compile core sources itself.

## Reusable solutions

- [Parser fault precedence](parser-precedence-reading.md) — why `parseGrid` is two passes, and the one RTVM self-conflict (TP-106's interior space) awaiting a ruling.
- [Making invariants compile-time](making-invariants-compile-time.md) — the enum/static_assert/exhaustive-switch tricks this project uses instead of runtime checks.
- [Solver search shape](solver-search-shape.md) — one search covers RTVM-200/201/202; measured margins and which mutations TP-200 can't catch.

## Process

- [Unit tests are the Software Engineer's to write](unit-tests-are-the-software-engineers-to-write.md) — Test Engineer is hook-blocked from writing files; ship TEST_METHODs with the feature.

## Coding standards

- `docs/SDD.md` §2.1–§2.9 is the authoritative standard for this project (naming, const-correctness, `enum class`, no raw `new`, test methods prefixed with the RTVM ID they verify).

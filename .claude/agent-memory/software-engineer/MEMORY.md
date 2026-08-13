# Software Engineer — memory

## Architecture patterns

- [SudokuSolver module layout](sudoku-module-layout.md) — the scaffold decisions that `DELIV` inspections read; don't undo them casually.

## Platform-specific notes

- [No MSVC in the agent runner](no-msvc-in-agent-runner.md) — runs are Linux/g++; how to compile-check a VS 2022 deliverable anyway.
- [CppUnitTestFramework and the static CRT](msvc-cppunittest-crt.md) — why a `/MT` exe forces the test project to compile core sources itself.

## Reusable solutions

- [Parser fault precedence](parser-precedence-reading.md) — why `parseGrid` is two passes, and the one RTVM self-conflict (TP-106's interior space) awaiting a ruling.

<!-- Algorithms or components already solved well enough to reuse rather
     than re-derive — what it does, where it lives, what it assumes. -->

## Coding standards

- `docs/SDD.md` §2.1–§2.9 is the authoritative standard for this project (naming, const-correctness, `enum class`, no raw `new`, test methods prefixed with the RTVM ID they verify).

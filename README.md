# SudokuSolver

A self-contained x64 Windows console application that reads a 9×9 Sudoku
puzzle, solves it, and prints the result.

> **Status: scaffold.** The sections below are the headings `docs/SDD.md`
> §3.4 requires. They are filled in under **RTVM-904**; what is written here
> now is only what is already true of the scaffold.

## Prerequisites

- Windows x64.
- Visual Studio 2022 with the **Desktop development with C++** workload.
  Nothing else — no package manager, no download, no third-party library
  (RTVM-902). The unit test framework comes from that workload.

<!-- TODO(RTVM-904): confirm the workload components a clean machine needs. -->

## Build

Open `SudokuSolver.sln`, select `Release|x64`, and Build Solution.

<!-- TODO(RTVM-904): the equivalent msbuild command line. -->

## Run

<!-- TODO(RTVM-904): a worked example command and its exact output. -->

## Input format

Nine lines of nine characters. `1`–`9` are givens;
Both **`0` and `.` mean an empty cell** and may be mixed in the same puzzle.

<!-- TODO(RTVM-904): line endings, trailing newline, whitespace handling,
     and content after the ninth line. -->

## Exit codes

<!-- TODO(RTVM-904): the 0 / 1 / 2 / 3 table. -->

## Samples

`samples/` ships five puzzles: `easy.txt`, `hard17.txt`, `unsolvable.txt`,
`malformed.txt`, `nonunique.txt`. The build copies them beside the
executable.

<!-- TODO(RTVM-904, RTVM-907): the outcome each sample is expected to
     produce. -->

## Tests

The solution contains a `SudokuSolver.Tests` project. Run it from Test
Explorer in Visual Studio, or from the command line:

```
vstest.console.exe /Platform:x64 x64\Release\SudokuSolver.Tests.dll
```

<!-- TODO(RTVM-904, RTVM-905): the fast-subset command and what a pass
     looks like. -->

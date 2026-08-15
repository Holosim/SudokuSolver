# SudokuSolver

A self-contained x64 Windows console application that reads a 9×9 Sudoku
puzzle, solves it, and prints the result.

## Prerequisites

- Windows x64.
- Visual Studio 2022 with the **Desktop development with C++** workload.
  Nothing else — no package manager, no download, no third-party library
  (RTVM-902). The unit test framework (`Microsoft::VisualStudio::CppUnitTestFramework`)
  comes from that workload.

## Build

Open `SudokuSolver.sln`, select `Release|x64`, and Build Solution.

Equivalently, from a Visual Studio Developer Command Prompt:

```
msbuild SudokuSolver.sln /p:Configuration=Release /p:Platform=x64
```

The build produces `x64\Release\SudokuSolver.exe` and copies the five files
in `samples\` alongside it.

## Run

Pass the puzzle file as the first (and only) command-line argument:

```
x64\Release\SudokuSolver.exe samples\easy.txt
```

produces, on stdout, exactly:

```
+-------+-------+-------+
| 5 3 4 | 6 7 8 | 9 1 2 |
| 6 7 2 | 1 9 5 | 3 4 8 |
| 1 9 8 | 3 4 2 | 5 6 7 |
+-------+-------+-------+
| 8 5 9 | 7 6 1 | 4 2 3 |
| 4 2 6 | 8 5 3 | 7 9 1 |
| 7 1 3 | 9 2 4 | 8 5 6 |
+-------+-------+-------+
| 9 6 1 | 5 3 7 | 2 8 4 |
| 2 8 7 | 4 1 9 | 6 3 5 |
| 3 4 5 | 2 8 6 | 1 7 9 |
+-------+-------+-------+
```

and exits `0`. If no path is given, the puzzle is read from standard input
instead (`SudokuSolver.exe < samples\easy.txt` produces the same result).
Any arguments after the first are ignored.

## Input format

- Exactly 9 lines of exactly 9 characters each, describing the grid row by
  row.
- Each character is `1`–`9` (a given digit) or `0` or `.` (an empty cell) —
  both mean the same thing and may be mixed freely within one puzzle.
- Either LF or CRLF line endings are accepted, and a trailing newline after
  the ninth line is optional.
- Leading and trailing horizontal whitespace on a line is ignored; any other
  interior whitespace is treated as an illegal character.
- Content after the ninth line is ignored.

Input that does not match this shape, contains a character other than
`1`–`9`, `0` or `.`, or is self-contradictory (the same digit given twice in
a row, column, or 3×3 box) is rejected with a diagnostic on stderr and exit
code `1`; the solver never runs on it.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Solved — the grid is printed to stdout. If more than one solution exists, one solution is printed followed by a note that it is not unique. |
| `1` | Invalid input — the puzzle could not be read or did not parse. A diagnostic is written to stderr; nothing is written to stdout. |
| `2` | No solution — a plain statement is written to stdout that the puzzle has no solution. |
| `3` | Aborted — the user chose to stop a long-running solve. A message is written to stderr; nothing is written to stdout. |

No other exit code is reachable.

## Samples

`samples\` ships five puzzles, each demonstrating one outcome above. The
build copies all five beside the executable:

| File | Outcome |
| --- | --- |
| `easy.txt` | Solved (exit `0`) — a straightforward 30-given puzzle. |
| `hard17.txt` | Solved (exit `0`) — a 17-given puzzle, the minimum possible for a unique solution, used as the performance reference. |
| `unsolvable.txt` | No solution (exit `2`) — the givens are mutually consistent but no completion exists. |
| `malformed.txt` | Invalid input (exit `1`) — line 1 contains the illegal character `X`. |
| `nonunique.txt` | Solved, not unique (exit `0`) — has exactly two solutions; one is printed with the non-uniqueness note. |

For example:

```
x64\Release\SudokuSolver.exe samples\unsolvable.txt
```

prints `This puzzle has no solution.` to stdout and exits `2`.

## Tests

The solution contains a `SudokuSolver.Tests` project. Run it from Test
Explorer in Visual Studio, or from the command line:

```
:: everything
vstest.console.exe /Platform:x64 x64\Release\SudokuSolver.Tests.dll

:: fast subset (skips the tests that deliberately run up to 60 s)
vstest.console.exe /Platform:x64 x64\Release\SudokuSolver.Tests.dll ^
    /TestCaseFilter:"TestCategory!=Slow"
```

A passing run reports 0 failed tests in either case.

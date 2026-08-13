---
name: unit-tests-are-the-software-engineers-to-write
description: Test Engineer is blocked from writing any file, so committed unit tests in tests/SudokuSolver.Tests must come from the Software Engineer
metadata:
  type: project
---

The Test Engineer agent has a `PreToolUse` hook
(`scripts/guard-test-engineer-writes.sh`) that blocks **every** Edit/Write
outside its own memory folder. It verifies by building throwaway g++ drivers
in `/tmp`, which are gone when the run ends.

**Why:** a code change must always originate from, and be visible to, the
Software Engineer. The side effect is that nothing the Test Engineer runs ever
lands in the repository — so `tests/SudokuSolver.Tests` only grows if the
Software Engineer writes the `TEST_METHOD`s.

**How to apply:** ship the unit tests for your own RTVM items with the feature
(SDD §3.3 assigns TP-100…106, TP-200…204, TP-300…302 and TP-400 to that
project). Name each method `rtvm<nnn>_...` per SDD §2.2. Shared fixture data
belongs in `tests/SudokuSolver.Tests/TestFixtures.h`, transcribed from
`docs/RTVM.md` §6.1/§6.2 and nowhere else. Verify locally with the
`CppUnitTest.h` shim described in [[no-msvc-in-agent-runner]], and prove the
new tests are falsifiable by mutating the code under test before handing off.

Related: [[msvc-cppunittest-crt]], [[making-invariants-compile-time]]

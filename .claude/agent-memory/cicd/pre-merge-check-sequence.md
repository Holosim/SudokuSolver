---
name: pre-merge-check-sequence
description: The order of checks that makes a SudokuSolver trunk merge honest — conflict preview, build the merged content not the branch, TP-903 grep, and the git merge -F stdin quirk
metadata:
  type: project
---

The sequence that worked cleanly on #6, in order:

1. `git fetch --all --prune` then `git fetch --unshallow origin` — always first,
   see [[shallow-clone-merge-trap]].
2. **Preview conflicts before touching anything:**
   `git merge-tree $(git merge-base main issue-<n>) main issue-<n>`. Empty
   output means a clean merge; this is how you find out whether
   [[doc-conflicts-on-merge]] applies this time, rather than discovering it
   mid-merge. Also `git log --oneline <base>..main` to see what trunk did while
   the branch was open.
3. **Build the merged content, not the branch.** Merge first, then run the g++
   check on `main` with the merge in place. A branch that builds and a trunk
   that builds are different claims, and the second is the one the merge commit
   asserts. Push only after it passes.
4. **Run the unit suite on the merged tree, not just the build.** From #7 on
   there are real tests, and they're cheap to execute here. Generate the driver
   rather than hand-listing method names — regex `TEST_CLASS\((\w+)\)` /
   `TEST_METHOD\((\w+)\)` over `tests/SudokuSolver.Tests/*.cpp`, `#include` the
   `.cpp`s, emit one `{ ns::Cls t; t.method(); }` per hit. A hand-written list
   silently stops covering tests added later, which is the whole failure mode.
   The `/tmp/shim/CppUnitTest.h` stand-in needs `TEST_CLASS`→`class`,
   `TEST_METHOD`→`void f()`, and `Assert::IsTrue/IsFalse/AreEqual` (templated,
   plus a `const char*` overload). Link against `src/SudokuCore/*.cpp` **only**,
   with no console object file — that makes the run a live demonstration of the
   RTVM-903 layering split rather than a grep of it.
5. **Re-run TP-903's grep post-merge** (`\b9\b` over `src/SudokuCore`) — the
   only dimension `9` should be the `kGridSize` definition in `Grid.h`; other
   hits are comments and doc cross-references. Cheap, and it is the project's
   one structural invariant that a merge could silently break.
6. Spot-check `samples/*.txt` are still 90 bytes each, and that any `.vcxproj` /
   `.filters` change is one the issue actually called for (#7 legitimately added
   three test files to both). Parse every project file as XML, check each
   `ClCompile`/`ClInclude`/`None` `Include` resolves on disk, and check no
   source under `tests/` is missing from the project — a file that exists but
   isn't registered compiles fine under `g++` here and then doesn't run under
   MSVC, which is exactly the gap this runner can't otherwise see.

**Toolchain quirk:** `git merge -F -` does **not** read stdin — it fails with
`error: could not read file '-'` (exit 129). Long merge messages must go via a
real temp file (`git merge --no-ff issue-<n> -F /tmp/merge-msg.txt`). `git
commit -F -` does accept stdin, so the inconsistency is easy to trip over.

**Why:** the merge commit is the durable record of what shipped, so every claim
in it should have been executed against the state being pushed. Building the
branch and then describing trunk as buildable is the specific way to get that
subtly wrong.

**How to apply:** every `status:ready-for-commit` run. Note what these checks
*cannot* cover — see [[no-windows-build-verification]] — and say so explicitly
in both the commit body and the issue comment.
Related: [[branch-and-merge-conventions]].

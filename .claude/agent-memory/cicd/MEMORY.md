# CI/CD — memory

## Branching conventions

- [Branch & merge conventions](branch-and-merge-conventions.md) — `issue-<n>` branches, `--no-ff` merges, and why CI/CD never sets Verified.
- [Doc conflicts on merge](doc-conflicts-on-merge.md) — `docs/RTVM.md`/`SDD.md` conflict; resolve per-hunk, never whole-file.
- [Lock before merging docs](lock-before-merging-docs.md) — a merge that rewrites `docs/RTVM.md` is an edit; lock it, and verify on a scratch branch first.
- [Conflicts that are ID collisions](merge-conflicts-that-are-id-collisions.md) — two branches both append `I-17`; merge as a union, never renumber.
- [Fast-path RTVM update, nothing to commit](fast-path-rtvm-update-nothing-to-commit.md) — `status:ready-for-commit` can mean Systems Engineer already pushed the RTVM promotion directly to trunk; check `git status` before assuming a branch merge.
- [Docs-only merge, no build check](docs-only-merge-no-build-check.md) — a real 3-commit branch can still touch nothing under `src/`/`tests/`; skip the build step honestly, and don't overwrite an already-recorded evidence SHA with your merge SHA.
- [RTVM-506 re-verification merge](rtvm-506-reverification-merge.md) — second occurrence of the docs-only-real-branch shape (#14); confirms it's a recurring pattern, not a one-off.
- [Stale-branch real union conflicts](stale-branch-real-union-conflicts.md) — a branch cut before several other issues merged still narrows to a handful of real, additive-both-sides conflicts; resolve as a union, not a pick-one-side.
- [checkout -B keeps a dirty worktree](checkout-b-keeps-dirty-worktree.md) — switching branches with `checkout -B` doesn't discard a prior scratch branch's staged resolution; `git reset --hard` first, then restore your backed-up resolution.
- [Append-conflict closing-brace suffix](append-conflict-closing-brace-suffix.md) — two branches appending `TEST_METHOD`s to one file: git factors the identical trailing braces out, so the first side's last method silently needs its `}` put back.
- [Test-code-only merge still needs regression](test-code-only-merge-still-needs-regression.md) — #16: new `TEST_METHOD`s with zero `src/` change is a real code merge, not the docs-only carve-out; don't waive the regression-testing note.
- [RTVM promoted ahead of branch merge](rtvm-promoted-ahead-of-branch-merge.md) — #19: Systems Engineer pushed the RTVM promotion straight to `main` before the branch (real, unmerged PowerShell harness code) was merged; check the full branch diff, not just `docs/`, before reaching for the fast-path label.

## Build & toolchain notes

- [No Windows build verification](no-windows-build-verification.md) — Ubuntu runners vs. an MSVC deliverable: what a pre-merge build check can honestly claim.
- [Pre-merge check sequence](pre-merge-check-sequence.md) — conflict preview, build the *merged* content, TP-903 grep, and the `git merge -F -` stdin quirk.
- [Test-DLL link set grows](test-dll-link-set-grows.md) — since #10 the native-suite driver must also link `Messages.cpp`/`Reporter.cpp`, not `SudokuCore` alone; check the test `.vcxproj`'s `ClCompile` list, don't hardcode it.

## Release & versioning

<!-- Version numbering scheme and what triggers a release per product
     line. -->

## Known issues

- [Shallow-clone merge trap](shallow-clone-merge-trap.md) — "refusing to merge unrelated histories" is a depth-1 checkout, not a lost history. Fetch and unshallow first.
- [cwd and merge-tree reading gotchas](cwd-and-merge-tree-reading-gotchas.md) — cd to repo root before trusting path-filtered git log; `merge-tree` "changed in both" isn't a conflict until `<<<<<<<`, grep for it on large output; a revert-then-redo pair in `main`'s own history isn't yours to fix.

# CI/CD — memory

## Branching conventions

- [Branch & merge conventions](branch-and-merge-conventions.md) — `issue-<n>` branches, `--no-ff` merges, and why CI/CD never sets Verified.
- [Doc conflicts on merge](doc-conflicts-on-merge.md) — `docs/RTVM.md`/`SDD.md` conflict; resolve per-hunk, never whole-file.
- [Lock before merging docs](lock-before-merging-docs.md) — a merge that rewrites `docs/RTVM.md` is an edit; lock it, and verify on a scratch branch first.
- [Conflicts that are ID collisions](merge-conflicts-that-are-id-collisions.md) — two branches both append `I-17`; merge as a union, never renumber.

## Build & toolchain notes

- [No Windows build verification](no-windows-build-verification.md) — Ubuntu runners vs. an MSVC deliverable: what a pre-merge build check can honestly claim.
- [Pre-merge check sequence](pre-merge-check-sequence.md) — conflict preview, build the *merged* content, TP-903 grep, and the `git merge -F -` stdin quirk.
- [Test-DLL link set grows](test-dll-link-set-grows.md) — since #10 the native-suite driver must also link `Messages.cpp`/`Reporter.cpp`, not `SudokuCore` alone; check the test `.vcxproj`'s `ClCompile` list, don't hardcode it.

## Release & versioning

<!-- Version numbering scheme and what triggers a release per product
     line. -->

## Known issues

- [Shallow-clone merge trap](shallow-clone-merge-trap.md) — "refusing to merge unrelated histories" is a depth-1 checkout, not a lost history. Fetch and unshallow first.

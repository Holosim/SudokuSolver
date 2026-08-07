# CI/CD — memory

## Branching conventions

- [Branch & merge conventions](branch-and-merge-conventions.md) — `issue-<n>` branches, `--no-ff` merges, and why CI/CD never sets Verified.
- [Doc conflicts on merge](doc-conflicts-on-merge.md) — `docs/RTVM.md`/`SDD.md` conflict; resolve per-hunk, never whole-file.

## Build & toolchain notes

- [No Windows build verification](no-windows-build-verification.md) — Ubuntu runners vs. an MSVC deliverable: what a pre-merge build check can honestly claim.

## Release & versioning

<!-- Version numbering scheme and what triggers a release per product
     line. -->

## Known issues

- [Shallow-clone merge trap](shallow-clone-merge-trap.md) — "refusing to merge unrelated histories" is a depth-1 checkout, not a lost history. Fetch and unshallow first.

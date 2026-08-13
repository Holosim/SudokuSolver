---
name: making-invariants-compile-time
description: How this project turns "closed set" and "never none" requirements into build failures rather than test assertions — the pattern to reuse
metadata:
  type: project
---

`docs/SDD.md` §2.4/§2.6 state a house philosophy: an invalid state should be
*unrepresentable*, not merely untested (`SolveReport`, `ParseResult`). Three
mechanics implement it, all verified working on 2026-08-07 under issue #7:

- **Closed enum set** — `static_assert` on each enumerator's numeric value.
  Inserting a member shifts a value and fails the build; it also stops a
  renumbered outcome from being silently linked against an already-compiled TU.
- **No sixth member appended** — an exhaustive `switch` with **no `default`
  label** (`outcomeCarriesGrid` / `outcomeCarriesFault` in `SolveReport.cpp`).
  Appending an enumerator warns under gcc/clang `-Wswitch` and MSVC C4062 at
  /W4. Both mutations were confirmed to fire.
- **No "none" state** — `static_assert(!std::is_default_constructible_v<T>)`
  plus `!std::is_constructible_v<T, Outcome>` for the private ctor.
- **A record that must stay wording-free** — decompose it in a test with a
  structured binding naming every member
  (`const auto& [kind, line, ...] = fault;`). Adding a `message` field then
  fails to compile, which is a stronger guarantee than asserting a string is
  empty.

**How to apply:** reach for these before writing a runtime test for a
structural property, and say in the handoff comment which mutation you used to
prove the guard fires — the Test Engineer cannot add tests themselves
([[unit-tests-are-the-software-engineers-to-write]]).

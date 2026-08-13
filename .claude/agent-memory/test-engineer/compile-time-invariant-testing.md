---
name: compile-time-invariant-testing
description: How to actually verify this repo's static_assert/-Wswitch "tests" on the Linux runner — mutate a /tmp copy and check the build breaks — plus the private-ctor gotcha that produces a false negative.
metadata:
  type: feedback
---

Several requirements here are implemented as **compile-time** assertions
(`static_assert`, exhaustive `switch` with no `default`) rather than runtime
assertions — RTVM-300's "never none / never two" is the first example
(issue #7, 2026-08-07). A green build *is* the assertion, so running the test
binary proves nothing about them on its own.

**Rule:** for any requirement whose test is a `static_assert` or a warning,
verify it by mutation — `cp -r` the repo to `/tmp`, break the invariant with
`sed`/`python3`, rebuild, and confirm the build fails. Add `-Werror` so
`-Wswitch` counts as a failure the way MSVC C4062 at /W4 would.

**Why:** without this, a "pass" only says the code compiles, which it would do
just as happily if the assertion were vacuous or deleted. Establishing that the
tests are falsifiable is the whole of the verification for this class of
requirement. It also independently checks the Software Engineer's claim rather
than restating it.

**How to apply:** mutations worth running on a report/enum type like this —
insert an enumerator (pins numeric values), append one (exhaustive switches),
make a private ctor public, add a public default ctor, add a `std::string`
field a structured-binding test enumerates, drop a range check, have a factory
forget its payload, flip a row of the populated-field table. All of these were
caught on issue #7.

**Gotcha that cost a cycle:** adding `SolveReport() = default;` in the
**private** section does *not* trip
`static_assert(!std::is_default_constructible_v<...>)` — the trait is
evaluated from outside the class, so a private default ctor is still "not
default constructible". A mutation that builds clean is only meaningful if the
mutation is actually visible at the assertion's access context. Insert the
mutation into the `public:` section.

**Scope limit, ruled by the Systems Engineer 2026-08-13 (`docs/RTVM.md` §9.6):**
mutation evidence is required when a compile-time invariant is *first* verified,
and **not** on a later regression pass where the code is byte-identical —
re-deriving the mutation table then is re-testing the feature, not the merge.
If something in the regression run *does* fail, the mutation table is the
fastest way to localise it. §9.6 also now states the general convention: for a
compile-time assertion, state the mutation and its observed effect or the clause
counts as unverified.

See [[no-windows-runner]] and [[cppunittest-shim-gotchas]] for the harness the
mutated copy is built with.

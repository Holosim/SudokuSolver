---
name: doc-drift-is-not-a-failure
description: How to handle stale source comments that contradict a later §7 interpretation ruling — report as an observation to the Systems Engineer, never as a test failure.
metadata:
  type: feedback
---

When a `docs/RTVM.md` §7 interpretation is ruled *after* code was written, some
source comments in files the ruling did not touch will still state the old
reading. Report these as a **non-blocking observation to the Systems Engineer**,
explicitly not a failure, and do not hand the issue back to the Software
Engineer for it.

**Why:** a handback costs a full fail/rebuild/retest cycle and counts toward the
5-strike rule, for something with no behavioural effect and no procedure clause
hanging off it. Verified behaviour is what a test procedure asserts; a comment
is not. Found on issue #7's trunk regression (2026-08-13): `Grid.h` still said
the 0-based→1-based conversion happens "only in the output layer" after §7
**I-16** ruled it happens at fault construction.

**How to apply:** grep the core's comments for the terms a fresh §7 ruling uses
whenever one lands, and list any drift in the test comment under a clearly
labelled "no action needed to close this" heading, naming the file and line and
the cheapest moment to fix it (usually "whenever that file is next opened").
Related: [[trunk-regression-scope]].

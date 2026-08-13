---
name: stub-wording-vs-exit-codes
description: On this project the exit-code mapping lands whole and early while the message wording arrives per-issue, so a correct exit code with an empty stdout/stderr is expected state, not a defect.
metadata:
  type: project
---

`Reporter` has carried the **full RTVM-405 exit-code mapping since the
scaffold**, while `Messages` wording lands issue by issue. The recurring shape
is therefore: **right exit code, empty stream**.

Observed on #9 (2026-08-13) and consistent with #6's earlier note in
[[parser-test-scope-and-open-ruling]]:

| Input | Exit | Stream | Owning issue |
| --- | --- | --- | --- |
| `unsolvable.txt` | `2` | stdout empty (no "no solution" line) | #11 (RTVM-402) |
| `nonunique.txt` | `0` | grid printed, **note line absent** | #11 (RTVM-401) |
| `malformed.txt`, missing file | `1` | stderr empty | #10 (RTVM-403/RTVM-009) |

**Why:** each of these reads exactly like a real defect the first time, and
handing one back costs a whole fail/rebuild/retest cycle for code that was
never in scope.

**How to apply:** before reporting an empty stream as a failure, check whether
the *wording* belongs to a later issue while the *code path* belongs to this
one. Assert the exit code — that part is in scope and testable now — and say
in the comment which wording is deferred and to which issue. Anything else
empty or wrong **is** a real defect. The inverse trap matters too: a right
exit code proves nothing about the message, so don't credit a wording
requirement off an exit code alone.

---
name: handoff-label-missed-triggers-stall-recovery
description: A run can post its handoff comment and do the real merge, then never execute the gh issue edit relabel — stall-recovery re-triggers agent:cicd with nothing new to do.
metadata:
  type: known-issue
---

On #20 (RTVM-505), a prior CI/CD run completed the real work — merged
`issue-20` into `main` (`68c9cde`) and posted a correctly-formatted
handoff comment with `**Next:** agent:systems-engineer` — but the
final `gh issue edit` relabel step never ran (or didn't land). The
issue sat with `agent:cicd` + `status:in-progress` +
`status:ready-for-commit` still present, so `stall-recovery.yml`
re-triggered `agent:cicd` twice with an hour gap, even though nothing
was actually stuck.

**Why:** step 6 (the label handoff) is a separate action from step 5
(the comment) and step 4 (the commit/merge) — a run can complete 4 and
5 and still fail to execute 6, and nothing downstream will notice
except stall-recovery eventually re-poking the same role.

**How to apply:** when re-entering an issue that's back on
`agent:cicd` after a stall-recovery comment, don't assume the merge
still needs doing. Check `git log --oneline` on `main` for a merge
commit matching this issue number/RTVM ID first — if it's already
there, the only gap is likely the label swap. Post a short comment
confirming the state (with SHAs) rather than re-doing or second-guessing
the merge, then run the label handoff for real. See
[[branch-and-merge-conventions]].

---
name: windows-evidence-reading
description: How to reach and read windows-verification.yml evidence from an Ubuntu agent run, and the three surfaces that misreport a failed step as green
metadata:
  type: project
---

Windows verification runs as a separate `windows-verification.yml` on
`windows-latest`, push-triggered on `main` and `issue-*`. It publishes
evidence and never issues a verdict (W-2) — **the verdict is mine**.

**Reaching it from Ubuntu** (all within `actions: read`, no permission
issues):

```
gh run list --workflow=windows-verification.yml --limit 10
gh run view <id> --json status,conclusion,headSha
gh run download <id> -D /tmp/ev        # must be run from inside the repo
gh run view <id> --log | grep -F "TP-905"
```

**Never trust a green tick, and — measured 2026-08-13 — never trust the
step conclusion either.** Three surfaces lie in the same direction:

1. `continue-on-error: true` sets a failed step's **conclusion** to
   `success` while its *outcome* is failure. `gh api .../jobs` and the
   run UI both show green for a step that errored and produced nothing.
2. The summary table keys rows on "did an output file appear", so a step
   that ran and errored renders identically to one never attempted
   (`NOT-RUN`) — defect DW-2.
3. The job as a whole concludes `success` with failed steps inside it.

Only the raw log and its `##[error]` annotation tell the truth. Read the
log for every procedure I intend to rule on.

**`concurrency: cancel-in-progress: true` is keyed on the ref**, so a
rapid second push to `main` cancels the first run. Three of six `main`
runs on 2026-08-13 were cancelled this way, including the `issue-9`
merge commit's. Before ruling on a merge, check that evidence exists for
*that* SHA — or diff the product tree against the SHA that does have
evidence (`git diff --stat <merge> <evidenced> -- src tests *.sln
samples`; empty means the evidence covers it).

Machine facts (CPU, clock, image) change between runs on the same day —
EPYC 9V74 / 2596 MHz and EPYC 7763 / 2445 MHz hours apart. Always quote
`evidence/machine.md` from the same run (W-9).

See [[no-windows-runner]] for what the Ubuntu substitute toolchain can
and cannot prove, and [[test-engineer-cannot-author-repo-files]] for who
writes the procedure scripts.

---
name: verification-environment-policy
description: Standing rule for this project — nothing is Verified on a substitute toolchain; Windows-only clauses must run on Windows, with a justified client-acceptance list as the only fallback
metadata:
  type: project
---

The agent pipeline runs on Ubuntu; the deliverable is Windows/VS 2022. Resolved
on issue #23 (2026-08-07) and written into `docs/PROJECT_DEFINITION.md` §7.1 as
rules V-1…V-7.

**Why:** the clauses that cannot run on Ubuntu are exactly the ones the client
cares most about — the progress prompt, the abort, the performance budget, and
the openable VS solution. Letting a `g++` build or an XML read of a `.vcxproj`
stand in for MSVC would mean the interesting half of the MVP ships unverified,
and the failure would only surface at handover.

**How to apply:** any time a role reports that something "can't be tested here",
the answer is not to weaken the requirement or the procedure. Evidence gathered
on a substitute toolchain is evidence, never a verdict. The clause either moves
to a Windows runner (preferred — repo is public, so hosted Windows minutes are
free, and `docs/RTVM.md` §6.3 already names `windows-latest`) or onto a short,
individually-justified client-acceptance list that I surface to the client
*before* acceptance is claimed. Never a blanket "accept the gap".

**Permanent ceiling (settled 2026-08-13, §7.1.1 / V-10):** no agent in this
pipeline can create, update or dispatch a GitHub workflow — measured with the
live token, not inferred (`docs/RTVM.md` §9.1.4). And this is **not fixable by a
settings change**: the client established that the relay App declares only
Contents, Pull Requests and Issues, and an installer cannot grant a permission
an app never declared. So of the two options I put to them, only the hand-commit
was ever real — do not offer the permission grant again as if it were a
trade-off. Standing consequence: any future change to any workflow file is a
client action. Prepare the exact file under `docs/ci/` so the owner's step is
copy-and-commit, never design, and raise it early rather than letting it become
"accept the gap" by attrition. Windows CI itself is live as of `fc23901`.

Generalises beyond this project: whenever the build platform and the
verification platform diverge, make it a written decision with a named owner
early, rather than discovering it at the last test procedure.

Related: [[architect-owns-what-not-how]] — *how* Windows CI gets wired stayed
with the Systems Engineer; only the requirement that it happen is mine.

---
name: test-engineer-cannot-author-repo-files
description: The write guard blocks me from authoring even test-harness files like tests/windows/*.ps1 — spec them and hand to Software Engineer, don't route around it
metadata:
  type: feedback
---

I do not author or commit **any** repository file except my own memory,
even when another role assigns one to me and even when the file is
plainly test-side rather than product code.

**Why:** `scripts/guard-test-engineer-writes.sh` (a `PreToolUse` hook
declared in `.claude/agents/test-engineer.md`) allows exactly one path
prefix, `.claude/agent-memory/test-engineer/`. Its stated purpose is
that a repository change must originate from and be visible to the
Software Engineer. On 2026-08-13 the Systems Engineer and Solutions
Architect both assigned me `tests/windows/run-procedures.ps1` and
`run-timing.ps1` (W-10 — outside `.github/` so no permission round
trip). W-10 clears the *owner* permission wall; it does not clear this
guard, which is a second and separate wall in front of my role only. The
hook did not actually fire in that run — enforcement being absent is not
permission.

**How to apply:** when handed file-authoring work, produce a complete
specification instead — parameters, evidence-file contract, ordered
probe list, NOT-RUN rules, and the reason behind each clause — so the
Software Engineer implements and commits rather than designs. This
mirrors the project's own `docs/ci/` pattern (V-10). Then hand off to
`agent:software-engineer` and ask them to relay the durable fix upward:
adding `tests/windows/` to the guard's `ALLOWED_PREFIX` is a one-line
change to an agent-writable file, and it is a Systems Engineer decision,
not mine to make about my own guard.

Related: [[windows-evidence-reading]].

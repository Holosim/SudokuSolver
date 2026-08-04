# Requirements Traceability & Verification Matrix (RTVM)

**Product:** Sudoku Solver — Windows console application (C++ / Visual Studio 2022)
**Owner:** Systems Engineer
**Status:** ⚠️ **Line items pending.** Scope is not yet defined — see
"Open scope questions" below. No requirement may be entered into the matrix
until `docs/PROJECT_DEFINITION.md` exists and the questions below are answered
by the Solutions Architect.

This file currently records only the *conventions* the matrix will use, so that
IDs, categories, and verification vocabulary are stable before the first
requirement is written. It deliberately contains **no requirement line items** —
inventing them ahead of a defined scope would create traceability to nothing.

---

## 1. ID scheme

| Artifact | Format | Example | Notes |
|---|---|---|---|
| Stakeholder need | `SN-<n>` | `SN-3` | Owned by the Solutions Architect in `docs/PROJECT_DEFINITION.md`. |
| Requirement | `RTVM-<nnn>` | `RTVM-014` | Zero-padded to 3 digits. Allocated in blocks by category (below). Never renumbered or reused once issued — a withdrawn requirement stays in the table with status `Withdrawn`. |
| Test procedure | `TP-<nnn>[<letter>]` | `TP-014a` | Numeric part matches the requirement it verifies; the letter distinguishes multiple cases for one requirement. |

Every issue of `type:requirement` carries its ID in the title —
`[RTVM-014] Short description` — which is how commits, tests, and docs trace
back to the same requirement.

## 2. Category tags and ID blocks

Blocks follow the standard functional-area breakdown used for this template, so
an ID's number alone tells you which area it belongs to.

| Tag | Functional area | ID block |
|---|---|---|
| `UI` | User interface — console input/output, prompts, menus, arguments | `RTVM-001`–`RTVM-099` |
| `DATA-IN` | Internal data representation for input — puzzle parsing, grid model, validation | `RTVM-100`–`RTVM-199` |
| `CORE` | Core algorithm / processing logic — the solver itself | `RTVM-200`–`RTVM-299` |
| `DATA-OUT` | Internal data representation for output — solution/result model, metrics | `RTVM-300`–`RTVM-399` |
| `OUT` | Output / presentation — rendering, files, exit codes | `RTVM-400`–`RTVM-499` |
| `NFR` | Non-functional — performance, portability, error handling | `RTVM-500`–`RTVM-599` |
| `DELIV` | Deliverable requirements — build, toolchain, IDE-readiness. Verified by inspection, and specified in `docs/SDD.md` build conventions rather than by a runtime test. | `RTVM-900`–`RTVM-999` |

## 3. Verification method vocabulary

Exactly one of these per requirement:

- **Test** — executed against a build with defined inputs and expected outputs. The default; preferred wherever a requirement can be exercised.
- **Demonstration** — operated and observed, where the pass criterion is observable behaviour rather than a comparable output value (e.g. a prompt re-appears after bad input).
- **Analysis** — established by reasoning over measurements or code, e.g. a timing budget derived from benchmark runs.
- **Inspection** — established by examining the artifact, not running it. Used for `DELIV` items (e.g. the `.sln` opens and builds in VS 2022).

## 4. Status vocabulary

`Draft` → `Approved` → `In Implementation` → `In Test` → `Verified`
(plus `Blocked`, `Withdrawn`). Status is updated by the Systems Engineer as work
moves through the pipeline; `Verified` is set only after the Test Engineer
reports a pass.

## 5. Matrix

| ID | Cat | Requirement statement | SN(s) | Verification | Test proc. | Status |
|---|---|---|---|---|---|---|
| _(none yet)_ | — | Awaiting `docs/PROJECT_DEFINITION.md`. | — | — | — | — |

## 6. Open scope questions (RFI to Solutions Architect)

Raised on issue #1. Each answer converts directly into one or more line items
above; none can be safely assumed. Grouped by functional area.

### 6.1 User interface (`UI`)
1. **Primary input method for the MVP** — interactive cell-by-cell console entry, a puzzle file path passed as a command-line argument, a grid pasted into stdin, or a JSON/text config file? (The template material leans on JSON config; confirm whether that applies here.)
2. Is there any **mode/menu selection** (solve / validate / generate), or is the MVP a single solve action?
3. Should **built-in sample puzzles** ship with the app for demonstration, and is running one a requirement?

### 6.2 Input representation (`DATA-IN`)
4. **Grid size limits** — fixed 9×9 only, or must 4×4 / 16×16 variants be supported? If only 9×9, is that a hard constraint or a first-tier limit?
5. Which characters denote an **empty cell** on input — `0`, `.`, space, any of them?
6. On **malformed input** (wrong cell count, illegal character): exit with a message, or re-prompt? What exit code, if any?
7. On a **contradictory-but-well-formed** puzzle (e.g. duplicate 5 in a row): rejected up front as invalid, or handed to the solver to fail as unsolvable?

### 6.3 Core algorithm (`CORE`)
8. Is a **specific algorithm mandated** (e.g. constraint propagation plus backtracking) because the client wants a particular approach demonstrated, or is any correct method acceptable?
9. **Performance budget** — what is the maximum acceptable solve time, and against what class of puzzle (e.g. a hard 17-clue grid in under 1 second on a typical desktop)? A number is needed to make this verifiable.
10. **Multiple solutions** — return the first solution found, count all solutions, or detect and report that a puzzle is not uniquely solvable?
11. Is a **solve trace** (steps or techniques applied) required, or is the final grid sufficient?

### 6.4 Output (`DATA-OUT`, `OUT`)
12. **Output format** — pretty-printed grid with box separators, a plain 81-character string, or both? To stdout only, or also written to a file?
13. Should **metrics** be reported (elapsed time, backtrack/guess count)?
14. Do **process exit codes** matter (success / invalid input / unsolvable), i.e. does anyone need to script this?

### 6.5 Deliverable requirements (`DELIV`)
15. Confirm the deliverable: VS 2022 solution and project files committed, target **C++ standard** (C++17 or C++20), x64 Windows console, **no third-party dependencies**? Is a cross-platform CMake build also wanted, or is VS-only acceptable?
16. Who **maintains and extends** this afterwards — is "a client engineer can open the `.sln` and add a feature" an explicit acceptance criterion, or is the working executable the whole deliverable?
17. Preference for an **automated test framework** versus the Test Engineer executing manual console procedures? This determines how test procedures in this matrix are written.

### 6.6 Priority tiering
18. What is the **minimum shippable MVP** — e.g. "read a valid 9×9 puzzle from a file, solve it, print the grid"? Which of the items above belong to later tiers? Needed before `docs/IMPLEMENTATION_PLAN.md` can sequence the build.

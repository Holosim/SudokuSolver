# Common.ps1 — shared helpers for the Windows evidence scripts.
#
# Dot-sourced by run-procedures.ps1 and run-timing.ps1. Lives under
# tests/windows/ (agent-writable, W-10) rather than in the workflow file
# (owner-gated, V-10) so it can be revised without a round trip.
#
# Contract this file exists to uphold — docs/RTVM.md §9.1's §5 spec,
# issue #23:
#   C1 — callers never throw out of a probe; everything is evidence.
#   C2 — evidence JSON schema, written by the caller via Write-EvidenceJson.
#   C3 — state is PASS / FAIL / NOT-RUN only; NOT-RUN requires a reason.
#   C4 — evidence, never verdict (W-2). No labels, no requirement status.
#   C5 — every check names the TP id it feeds.
#   C6 — machine facts come from <EvidenceDir>/machine.md of *this* job
#        (W-9), never assumed or carried from a previous run.
#   C7 — nothing here is added to any .vcxproj (D-7, V-7).

Set-StrictMode -Off

# ---------------------------------------------------------------------------
# Evidence ledger
# ---------------------------------------------------------------------------

function New-CheckList {
    $list = [System.Collections.Generic.List[object]]::new()
    # The leading comma matters: without it, PowerShell's pipeline output
    # unrolls the (empty) List into zero output objects and the caller's
    # $Checks silently becomes $null - every Add-Check call after that
    # fails with "Cannot bind argument to parameter 'Checks' because it is
    # null", and because that happens deep inside a try/catch it can look
    # like an unrelated crash. Measured, not theoretical - see the
    # 2026-08-13 issue #23 handoff comment.
    return , $list
}

# Adds one row to the evidence ledger. State must be PASS/FAIL/NOT-RUN (C3);
# NOT-RUN requires a non-empty $Reason. Never throws (C1) — a bad call here
# records itself as evidence instead of crashing the whole script.
function Add-Check {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Checks,
        [Parameter(Mandatory)][string]$Tp,
        [Parameter(Mandatory)][string]$Case,
        [Parameter(Mandatory)][ValidateSet('PASS', 'FAIL', 'NOT-RUN')][string]$State,
        $Expected = $null,
        $Observed = $null,
        [string]$Reason = $null
    )

    if ($State -eq 'NOT-RUN' -and [string]::IsNullOrWhiteSpace($Reason)) {
        $State = 'FAIL'
        $Reason = "internal: NOT-RUN requested for $Tp/$Case with no reason (C3) - recorded as FAIL instead of silently dropping the row"
    }

    $Checks.Add([ordered]@{
        tp       = $Tp
        case     = $Case
        state    = $State
        expected = $Expected
        observed = $Observed
        reason   = $Reason
    })
}

# Reads the machine block written earlier in *this* job (W-9). Never reaches
# back to a previous run's artifact.
function Read-MachineBlock {
    param([Parameter(Mandatory)][string]$EvidenceDir)

    $path = Join-Path $EvidenceDir 'machine.md'
    if (Test-Path -LiteralPath $path) {
        try {
            return (Get-Content -LiteralPath $path -Raw)
        }
        catch {
            return "machine.md present but unreadable in this job: $($_.Exception.Message)"
        }
    }
    return 'machine.md not found in this job (W-9) - no prior-run machine fact substituted'
}

function Get-CommitSha {
    param([string]$RepoRoot)

    if ($env:GITHUB_SHA) { return $env:GITHUB_SHA }
    try {
        if ($RepoRoot) {
            return (git -C $RepoRoot rev-parse HEAD 2>$null).Trim()
        }
        return (git rev-parse HEAD 2>$null).Trim()
    }
    catch {
        return 'unknown'
    }
}

# Writes the evidence contract (C2). $Checks is the list built with
# Add-Check. Also writes a human-readable .txt alongside, named the same as
# $Path with a .txt extension in place of .json.
function Write-EvidenceJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Checks,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Sha,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Machine
    )

    $doc = [ordered]@{
        schema       = 1
        sha          = $Sha
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        machine      = $Machine
        checks       = $Checks
    }

    $json = $doc | ConvertTo-Json -Depth 10
    Write-Utf8NoBom -Path $Path -Content $json

    $txtPath = [System.IO.Path]::ChangeExtension($Path, '.txt')
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Generated: $($doc.generatedUtc)  SHA: $Sha")
    $lines.Add('')
    foreach ($c in $Checks) {
        $lines.Add("[$($c.state)] $($c.tp) / $($c.case)")
        if ($c.reason) { $lines.Add("    reason:   $($c.reason)") }
        if ($null -ne $c.expected) { $lines.Add("    expected: $($c.expected)") }
        if ($null -ne $c.observed) { $lines.Add("    observed: $($c.observed)") }
    }
    Write-Utf8NoBom -Path $txtPath -Content ($lines -join "`n")
}

# ---------------------------------------------------------------------------
# Text / file helpers
# ---------------------------------------------------------------------------

# Writes text verbatim, UTF-8, no BOM, exactly the line endings already in
# $Content (never the environment default CRLF that Out-File would apply).
function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

# CRLF -> LF (and bare CR -> LF), for comparing a Windows text-mode build's
# stdout against the LF fixtures in docs/RTVM.md §6 (§6.1's own normalisation
# rule).
function ConvertTo-NormalizedText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    return ($Text -replace "`r`n", "`n") -replace "`r", "`n"
}

# Renders a 9-line solution (array of 9 nine-character strings) into the
# §6.2 13-line block. Used only where the literal block isn't quoted
# verbatim in the RTVM already, so a bug here can't silently redefine
# §6.2 — see the self-check in Fixtures.ps1.
function ConvertTo-GridBlock {
    # Deliberately not [Parameter(Mandatory)]: a mandatory [string[]]
    # rejects a single-element array whose one element is an empty string
    # with a confusing "it is an empty string" error, even with
    # [AllowEmptyCollection()] - the Count-9 check below is the real and
    # much clearer validation for this function anyway.
    param([string[]]$Rows)

    if (-not $Rows -or $Rows.Count -ne 9) { throw "ConvertTo-GridBlock expects 9 rows, got $(if ($Rows) { $Rows.Count } else { 0 })" }
    $sep = '+-------+-------+-------+'
    $lines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt 9; $i++) {
        if ($i % 3 -eq 0) { $lines.Add($sep) }
        $row = $Rows[$i]
        $groups = for ($g = 0; $g -lt 3; $g++) {
            ($row.Substring($g * 3, 3).ToCharArray() -join ' ')
        }
        $lines.Add('| ' + ($groups -join ' | ') + ' |')
    }
    $lines.Add($sep)
    return ($lines -join "`n") + "`n"
}

# Structural shape check for a §6.2 grid block: 13 lines, separators in the
# right place, each grid line 25 chars matching the normative regex, pure
# ASCII. Returns @{ Ok; Detail }. Used where the exact grid contents aren't
# asserted (TP-401 — either S-NONUNIQUE-A or -B is acceptable).
function Test-GridBlockShape {
    # Not [Parameter(Mandatory)] - see the comment on ConvertTo-GridBlock's
    # $Rows: a single-element string[] holding "" (exactly what an empty
    # stdout capture -split "`n" produces) trips PowerShell's mandatory
    # empty-string check even under [AllowEmptyCollection()].
    param([string[]]$Lines)

    if (-not $Lines -or $Lines.Count -lt 13) {
        $count = if ($Lines) { $Lines.Count } else { 0 }
        return @{ Ok = $false; Detail = "fewer than 13 lines ($count)" }
    }
    $sep = '+-------+-------+-------+'
    for ($i = 0; $i -lt 13; $i++) {
        $line = $Lines[$i]
        if ($i % 4 -eq 0) {
            if ($line -ne $sep) { return @{ Ok = $false; Detail = "line $($i + 1) expected separator, got '$line'" } }
        }
        else {
            if ($line.Length -ne 25 -or $line -notmatch '^\| \d \d \d \| \d \d \d \| \d \d \d \|$') {
                return @{ Ok = $false; Detail = "line $($i + 1) failed the grid-line regex: '$line'" }
            }
        }
        foreach ($ch in $line.ToCharArray()) {
            if ([int][char]$ch -gt 0x7F) { return @{ Ok = $false; Detail = "line $($i + 1) contains a non-ASCII character" } }
        }
    }
    return @{ Ok = $true; Detail = 'shape OK' }
}

function ConvertTo-FullWidthDigits {
    param([Parameter(Mandatory)][string]$Text)

    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        if ($ch -ge '0' -and $ch -le '9') {
            [void]$sb.Append([char](0xFF10 + ([int][char]$ch - [int][char]'0')))
        }
        else {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString()
}

# Substrings that indicate an unhandled CRT/OS crash surfaced as text
# rather than a controlled exit (RTVM-505 / TP-505's "no unhandled-exception
# text" clause).
$script:CrashIndicators = @(
    'Unhandled exception', 'unhandled exception', 'terminate called',
    'abort() has been called', 'Debug Error', 'Runtime Error',
    'has stopped working', 'Access violation', 'Segmentation fault',
    'This application has requested the Runtime to terminate'
)

function Test-ContainsCrashText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    foreach ($needle in $script:CrashIndicators) {
        if ($Text.Contains($needle)) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Locating the Visual Studio toolset (vswhere / vstest.console.exe)
# ---------------------------------------------------------------------------

# Never throws (C1) - falls back to the well-known default install path if
# %ProgramFiles(x86)% isn't set, rather than letting Join-Path reject a
# null Path and take out the whole calling section.
function Get-VsWherePath {
    try {
        $pfx86 = ${env:ProgramFiles(x86)}
        if (-not $pfx86) { $pfx86 = 'C:\Program Files (x86)' }
        # -ErrorAction Stop: Join-Path's own failures (e.g. an unresolvable
        # drive) are non-terminating by default, which try/catch does not
        # intercept - without Stop this would print straight to the job log
        # instead of being handled below.
        return (Join-Path $pfx86 'Microsoft Visual Studio\Installer\vswhere.exe' -ErrorAction Stop)
    }
    catch {
        return $null
    }
}

# ---------------------------------------------------------------------------
# Running the executable under test
# ---------------------------------------------------------------------------

# Runs $Exe with stdout/stderr captured to separate files (RTVM Test
# Procedures preamble: "stdout and stderr are captured separately").
# stdin is redirected from $StdinFile, or from a freshly-created empty file
# (a genuinely closed stdin - reads return EOF immediately) if $StdinFile is
# not given — never inherited from the calling shell, which under a CI job
# has no interactive console anyway.
#
# The empty file, not the literal string 'NUL', is deliberate: measured on
# the real Windows runner (Test Engineer, issue #23, 2026-08-13),
# Start-Process -RedirectStandardInput 'NUL' throws before the child process
# launches. The exception was being caught correctly per C1, but every case
# omitting -StdinFile then failed identically (39 rows, ~0.5ms "elapsed" -
# too fast to be the product) and several of those false failures were
# themselves masked as false PASSes downstream (TP-406 read the resulting
# empty stdout as "contains no forbidden substrings"; TP-500 timed the
# launch failure instead of the solver). A real empty file redirects and
# behaves the same as the closed-stdin semantics this was meant to express.
#
# Returns @{ ExitCode; TimedOut; ElapsedMs; StdoutBytes; StderrBytes }.
# Never throws (C1): a launch failure is reported as TimedOut = $false,
# ExitCode = -1, with the reason in the sibling field 'LaunchError'.
function Invoke-Sudoku {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$ArgList = @(),
        [string]$StdinFile = $null,
        [Parameter(Mandatory)][string]$OutFile,
        [Parameter(Mandatory)][string]$ErrFile,
        [hashtable]$EnvVars = @{},
        [int]$TimeoutSec = 60
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ErrFile) | Out-Null
    '' | Out-File -LiteralPath $OutFile -Encoding utf8 -NoNewline
    '' | Out-File -LiteralPath $ErrFile -Encoding utf8 -NoNewline

    $ownStdinFile = $null
    if ($StdinFile) {
        $stdin = $StdinFile
    }
    else {
        # New-TemporaryFile / [IO.Path]::GetTempFileName() both create a
        # real, empty, zero-byte file - redirecting stdin from it gives an
        # immediate EOF, same observable behaviour the NUL-device literal
        # was meant to have, without hitting whatever Start-Process does
        # differently for a reserved device name.
        $ownStdinFile = [System.IO.Path]::GetTempFileName()
        $stdin = $ownStdinFile
    }

    $previous = @{}
    foreach ($k in $EnvVars.Keys) {
        $previous[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, [string]$EnvVars[$k])
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $startArgs = @{
            FilePath               = $Exe
            RedirectStandardInput  = $stdin
            RedirectStandardOutput = $OutFile
            RedirectStandardError  = $ErrFile
            NoNewWindow             = $true
            PassThru                = $true
            # Start-Process reports a bad launch (e.g. a stdin redirect
            # target that doesn't resolve) as a non-terminating error,
            # which try/catch does not intercept and which would otherwise
            # print straight to the job log even though this function
            # handles the failure. -Stop turns it into a terminating error
            # so the catch block below is what actually deals with it.
            ErrorAction              = 'Stop'
        }
        if ($ArgList -and $ArgList.Count -gt 0) { $startArgs['ArgumentList'] = $ArgList }

        $proc = Start-Process @startArgs
        $finished = $proc.WaitForExit($TimeoutSec * 1000)
        $sw.Stop()

        if (-not $finished) {
            try { $proc.Kill() } catch { }
            return @{
                ExitCode    = -1
                TimedOut    = $true
                ElapsedMs   = $sw.Elapsed.TotalMilliseconds
                StdoutBytes = (Get-Item -LiteralPath $OutFile).Length
                StderrBytes = (Get-Item -LiteralPath $ErrFile).Length
                LaunchError = $null
            }
        }

        return @{
            ExitCode    = $proc.ExitCode
            TimedOut    = $false
            ElapsedMs   = $sw.Elapsed.TotalMilliseconds
            StdoutBytes = (Get-Item -LiteralPath $OutFile).Length
            StderrBytes = (Get-Item -LiteralPath $ErrFile).Length
            LaunchError = $null
        }
    }
    catch {
        $sw.Stop()
        return @{
            ExitCode    = -1
            TimedOut    = $false
            ElapsedMs   = $sw.Elapsed.TotalMilliseconds
            StdoutBytes = 0
            StderrBytes = 0
            LaunchError = $_.Exception.Message
        }
    }
    finally {
        foreach ($k in $EnvVars.Keys) { [Environment]::SetEnvironmentVariable($k, $previous[$k]) }
        if ($ownStdinFile) {
            try { Remove-Item -LiteralPath $ownStdinFile -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}

# Chooses the Reason for a FAIL row: a launch failure (Invoke-Sudoku's
# LaunchError - the process never ran at all) is a materially different and
# more informative fact than "the assertion didn't hold", so it always takes
# precedence over $Fallback. Without this, a harness bug that stops the
# product from launching reads identically to the product itself failing
# the check (Test Engineer, issue #23, 2026-08-13).
function Get-FailureReason {
    param(
        [Parameter(Mandatory)][hashtable]$Result,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Fallback
    )
    if ($Result.ExitCode -eq -1 -and $Result.LaunchError) {
        return "process failed to launch: $($Result.LaunchError)"
    }
    return $Fallback
}

# Probes whether the RTVM-507 diagnostic hook (SUDOKU_DIAG_MIN_SOLVE_MS) is
# observably active: run P-EASY with the variable set to a value stretching
# well past a normal solve, with a short wall-clock ceiling. If the process
# is still running when the ceiling is hit, the hook is (at least) doing
# something; if it exits promptly, the hook had no observable effect. Either
# way this never blocks the caller for longer than $ProbeCeilingSec.
function Test-DiagHookActive {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string]$FixtureFile,
        [Parameter(Mandatory)][string]$EvidenceDir,
        [int]$HookMs = 20000,
        [int]$ProbeCeilingSec = 5
    )

    $outFile = Join-Path $EvidenceDir 'hook-probe/stdout.txt'
    $errFile = Join-Path $EvidenceDir 'hook-probe/stderr.txt'
    $result = Invoke-Sudoku -Exe $Exe -ArgList @($FixtureFile) -OutFile $outFile -ErrFile $errFile `
        -EnvVars @{ SUDOKU_DIAG_MIN_SOLVE_MS = $HookMs } -TimeoutSec $ProbeCeilingSec

    if ($result.TimedOut) {
        return @{
            Active = $true
            Reason = "SUDOKU_DIAG_MIN_SOLVE_MS=$HookMs - process still running after the ${ProbeCeilingSec}s probe ceiling; hook appears active but this script does not yet drive its interactive prompt/abort protocol"
        }
    }

    return @{
        Active = $false
        Reason = "SUDOKU_DIAG_MIN_SOLVE_MS=$HookMs had no observable effect - P-EASY completed in $([math]::Round($result.ElapsedMs, 1))ms (exit $($result.ExitCode)); RTVM-507 hook not yet wired into main.cpp (see src/SudokuSolver/main.cpp diagnosticMinSolveDuration())"
    }
}

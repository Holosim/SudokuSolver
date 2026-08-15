#requires -Version 5.1
<#
.SYNOPSIS
    Windows evidence for the runtime/CLI test procedures, plus the two
    §9.4 automation probes (vstest discovery/execution and VS instance
    enumeration).

.DESCRIPTION
    Invoked by .github/workflows/windows-verification.yml (installed from
    docs/ci/windows-verification.yml) if this file is present; absent =
    NOT-RUN in the workflow summary, never a pass (V-6). Lives here, not in
    the workflow, so it can be added to and revised without a
    workflows-permission round trip (W-10, V-10).

    Full specification: issue #23, Test Engineer comment "Specification —
    the two scripts" (2026-08-13), sections P1-P5, contract C1-C7.
    Policy: docs/PROJECT_DEFINITION.md §7.1 (V-1..V-9). Wiring:
    docs/RTVM.md §9.1.3 (W-1..W-11).

    C1 governs the shape of this file: every probe is wrapped so a single
    failure becomes an evidence row, never an unhandled exception that
    would make the whole run look like NOT-RUN (indistinguishable from
    this script being absent). The JSON is written in a `finally`.

.PARAMETER Exe
    Path to the built SudokuSolver.exe (Release|x64 expected, not
    enforced here - see run-timing.ps1 for the build-configuration check).

.PARAMETER EvidenceDir
    Directory the workflow publishes as the windows-evidence-<sha>
    artifact. This script writes runtime-procedures.json/.txt here (C2),
    plus per-case raw stdout/stderr under <EvidenceDir>/runs/.

.PARAMETER TestDll
    Path to SudokuSolver.Tests.dll. Auto-discovered under
    **\x64\Release\ next to $Exe, or under $RepoRoot, if not given - the
    installed workflow does not pass it (per spec).

.PARAMETER RepoRoot
    Repository root, for locating samples/ and git metadata. Defaults to
    two levels above this script (tests/windows/..\..).
#>
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$EvidenceDir,
    [string]$TestDll,
    [string]$RepoRoot
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Fixtures.ps1')
. (Join-Path $PSScriptRoot 'lib/ConPty.ps1')

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

$Checks = New-CheckList
$Machine = Read-MachineBlock -EvidenceDir $EvidenceDir
$Sha = Get-CommitSha -RepoRoot $RepoRoot
$RunsDir = Join-Path $EvidenceDir 'runs'
$SamplesDir = Join-Path $RepoRoot 'samples'

# Everything below is wrapped so that C1 holds even for a failure this
# script's own section-level try/catch doesn't reach (e.g. fixture setup,
# which runs between sections, not inside one). The JSON is always written
# in the `finally`, and the script always exits 0 - a non-zero exit here
# would make a real failure indistinguishable from the script being absent
# (NOT-RUN), which is exactly the ambiguity C1 exists to remove.
try {

# A section runner: every P1-P5 block is independent evidence. One
# section throwing must not cost the others their evidence (C1).
function Invoke-Section {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)
    try {
        & $Body
    }
    catch {
        Add-Check -Checks $Checks -Tp $Name -Case 'section' -State 'FAIL' `
            -Reason "unhandled exception in this section: $($_.Exception.Message)" `
            -Observed $_.ScriptStackTrace
    }
}

# ===========================================================================
# P2 — VS instance enumeration (settles §9.4 A-2). Cheap; run first.
# ===========================================================================
Invoke-Section -Name 'TP-900/901' -Body {
    $vswhere = Get-VsWherePath
    if (-not $vswhere -or -not (Test-Path -LiteralPath $vswhere)) {
        Add-Check -Checks $Checks -Tp 'TP-900/901' -Case 'vs-instance-enumeration' -State 'NOT-RUN' `
            -Reason "vswhere.exe not found (resolved path: $(if ($vswhere) { $vswhere } else { 'could not be resolved' }))"
        return
    }

    $rawLines = & $vswhere -legacy -all -products * -format json 2>&1
    $jsonText = ($rawLines -join "`n")
    Write-Utf8NoBom -Path (Join-Path $EvidenceDir 'vswhere-raw.json') -Content $jsonText

    $instances = @()
    try { $instances = $jsonText | ConvertFrom-Json } catch { $instances = @() }

    $enriched = foreach ($inst in $instances) {
        $devenv = Join-Path $inst.installationPath 'Common7\IDE\devenv.exe'
        $devenvVersion = $null
        if (Test-Path -LiteralPath $devenv) {
            try { $devenvVersion = (Get-Item -LiteralPath $devenv).VersionInfo.FileVersion } catch { }
        }
        [ordered]@{
            instanceId          = $inst.instanceId
            displayName         = $inst.displayName
            installationVersion = $inst.installationVersion
            installationPath    = $inst.installationPath
            devenvPresent       = [bool]$devenvVersion -or (Test-Path -LiteralPath $devenv)
            devenvFileVersion   = $devenvVersion
        }
    }
    Write-Utf8NoBom -Path (Join-Path $EvidenceDir 'vswhere-instances.json') -Content ($enriched | ConvertTo-Json -Depth 6)

    $has17 = @($instances | Where-Object { $_.installationVersion -like '17.*' })
    if ($has17.Count -gt 0) {
        Add-Check -Checks $Checks -Tp 'TP-900/901' -Case 'vs-instance-enumeration' -State 'PASS' `
            -Expected 'a VS 17.x (2022) instance would make the TP-900/901 loader clause automatable via devenv.exe /Build' `
            -Observed "found $($has17.Count) instance(s) with installationVersion 17.x: $(($has17 | ForEach-Object { $_.installationVersion }) -join ', ')" `
            -Reason 'the loader clause is now automatable (§9.4 A-2) - see Test Engineer for follow-up automation'
    }
    else {
        $versions = ($instances | ForEach-Object { $_.installationVersion }) -join ', '
        Add-Check -Checks $Checks -Tp 'TP-900/901' -Case 'vs-instance-enumeration' -State 'NOT-RUN' `
            -Observed "instance versions on this image: $versions" `
            -Reason 'no VS 17.x (2022) instance present on this image - the TP-900/901 loader clause cannot be automated here (§9.4 A-2 candidate)'
    }
}

# ===========================================================================
# P1 — vstest discovery and execution (closes §9.4 A-3; fixes DW-1).
# ===========================================================================
Invoke-Section -Name 'TP-905' -Body {
    $vswhere = Get-VsWherePath
    if (-not $vswhere -or -not (Test-Path -LiteralPath $vswhere)) {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'discovery' -State 'NOT-RUN' -Reason "vswhere.exe not found (resolved path: $(if ($vswhere) { $vswhere } else { 'could not be resolved' }))"
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'execution' -State 'NOT-RUN' -Reason "vswhere.exe not found (resolved path: $(if ($vswhere) { $vswhere } else { 'could not be resolved' }))"
        return
    }

    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath
    if (-not $vsPath) {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'discovery' -State 'NOT-RUN' -Reason 'vswhere found no NativeDesktop-workload VS installation'
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'execution' -State 'NOT-RUN' -Reason 'vswhere found no NativeDesktop-workload VS installation'
        return
    }

    $vstest = Join-Path $vsPath 'Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe'
    if (-not (Test-Path -LiteralPath $vstest)) {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'discovery' -State 'NOT-RUN' -Reason "vstest.console.exe not found under $vsPath"
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'execution' -State 'NOT-RUN' -Reason "vstest.console.exe not found under $vsPath"
        return
    }

    if (-not $TestDll) {
        $fromExeDir = Join-Path (Split-Path -Parent $Exe) 'SudokuSolver.Tests.dll'
        if (Test-Path -LiteralPath $fromExeDir) {
            $TestDll = $fromExeDir
        }
        else {
            $found = Get-ChildItem -Path $RepoRoot -Recurse -Filter 'SudokuSolver.Tests.dll' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\x64\\Release\\' } | Select-Object -First 1
            if ($found) { $TestDll = $found.FullName }
        }
    }

    if (-not $TestDll -or -not (Test-Path -LiteralPath $TestDll)) {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'discovery' -State 'NOT-RUN' -Reason 'SudokuSolver.Tests.dll not found under x64\Release - build artifacts absent this run'
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'execution' -State 'NOT-RUN' -Reason 'SudokuSolver.Tests.dll not found under x64\Release - build artifacts absent this run'
        return
    }

    # --- Discovery: /ListTests:<container>, not an output path (DW-1). ---
    $discoveredPath = Join-Path $EvidenceDir 'discovered-tests.txt'
    $discoveryOutput = & $vstest "/ListTests:$TestDll" *>&1
    $discoveryExit = $LASTEXITCODE
    Write-Utf8NoBom -Path $discoveredPath -Content ($discoveryOutput -join "`n")

    # vstest's /ListTests output is a banner, then "The following Tests are
    # available:", then one fully-qualified test name per line.
    $names = New-Object System.Collections.Generic.List[string]
    $inList = $false
    foreach ($line in $discoveryOutput) {
        $text = [string]$line
        if ($text -match 'following Tests are available') { $inList = $true; continue }
        if ($inList) {
            $trimmed = $text.Trim()
            if ($trimmed.Length -gt 0) { $names.Add($trimmed) }
        }
    }

    if ($discoveryExit -eq 0 -and $names.Count -gt 0) {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'discovery' -State 'PASS' `
            -Expected 'vstest.console.exe /ListTests:<dll> exits 0 and lists at least one test' `
            -Observed "exit=$discoveryExit count=$($names.Count) names=$($names -join '; ')"
    }
    else {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'discovery' -State 'FAIL' `
            -Expected 'vstest.console.exe /ListTests:<dll> exits 0 and lists at least one test' `
            -Observed "exit=$discoveryExit count=$($names.Count)" `
            -Reason "see $($discoveredPath | Split-Path -Leaf) in the artifact for the raw vstest output"
    }

    # --- Execution: plain run + trx logger. ---
    $runOutputPath = Join-Path $EvidenceDir 'vstest-run.txt'
    $trxPath = Join-Path $EvidenceDir 'tests.trx'
    $runOutput = & $vstest $TestDll '/Platform:x64' '/Logger:trx;LogFileName=tests.trx' "/ResultsDirectory:$EvidenceDir" *>&1
    $runExit = $LASTEXITCODE
    Write-Utf8NoBom -Path $runOutputPath -Content ($runOutput -join "`n")

    if (-not (Test-Path -LiteralPath $trxPath)) {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'execution' -State 'NOT-RUN' `
            -Observed "vstest exit=$runExit" `
            -Reason 'tests.trx missing after the run - see vstest-run.txt in the artifact'
        return
    }

    try {
        [xml]$trx = Get-Content -LiteralPath $trxPath -Raw
        $counters = $trx.TestRun.ResultSummary.Counters
        $total = [int]$counters.total
        $passed = [int]$counters.passed
        $failed = [int]$counters.failed
        $state = if ($runExit -eq 0 -and $total -gt 0 -and $failed -eq 0) { 'PASS' } else { 'FAIL' }
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'execution' -State $state `
            -Expected 'all discovered tests run and pass, vstest exits 0' `
            -Observed "exit=$runExit total=$total passed=$passed failed=$failed" `
            -Reason $(if ($state -eq 'FAIL') { 'see tests.trx / vstest-run.txt in the artifact' } else { $null })
    }
    catch {
        Add-Check -Checks $Checks -Tp 'TP-905' -Case 'execution' -State 'NOT-RUN' `
            -Reason "tests.trx present but malformed: $($_.Exception.Message)"
    }
}

# ===========================================================================
# Fixtures on disk: prefer samples/*.txt (RTVM-907), generate the rest.
# ===========================================================================
$Fixtures = Get-Fixtures
$selfCheckFailures = Get-SelfCheckFailures
if ($selfCheckFailures.Count -gt 0) {
    Add-Check -Checks $Checks -Tp 'TP-400' -Case 'fixture-renderer-self-check' -State 'FAIL' `
        -Observed ($selfCheckFailures -join '; ') `
        -Reason 'ConvertTo-GridBlock disagrees with the literal §6.2 block - fixture-derived grid comparisons below are not trustworthy until this is fixed'
}
$FixtureDir = Join-Path $EvidenceDir 'fixtures'
$FixturePaths = Publish-Fixtures -Fixtures $Fixtures -Dir $FixtureDir -SamplesDir $SamplesDir
$SEasyBlock = Get-SEasyBlock

function New-RunPaths {
    param([Parameter(Mandatory)][string]$Case)
    $dir = Join-Path $RunsDir $Case
    return @{
        Dir = $dir
        Out = Join-Path $dir 'stdout.txt'
        Err = Join-Path $dir 'stderr.txt'
    }
}

# ===========================================================================
# P3 — runtime procedures against $Exe.
# ===========================================================================

# --- TP-002 - file argument. ---
Invoke-Section -Name 'TP-002' -Body {
    $easy = $FixturePaths['P-EASY']

    $p = New-RunPaths -Case 'TP-002-bare-file-arg'
    $r = Invoke-Sudoku -Exe $Exe -ArgList @($easy) -OutFile $p.Out -ErrFile $p.Err
    $stdout = ConvertTo-NormalizedText (Get-Content -LiteralPath $p.Out -Raw -ErrorAction SilentlyContinue)
    $pass = (-not $r.TimedOut) -and $r.ExitCode -eq 0 -and $r.StderrBytes -eq 0 -and $stdout -eq $SEasyBlock
    Add-Check -Checks $Checks -Tp 'TP-002' -Case 'bare-file-arg' -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
        -Expected 'stdout = S-EASY block, stderr empty, exit 0' `
        -Observed "exit=$($r.ExitCode) stderrBytes=$($r.StderrBytes) timedOut=$($r.TimedOut)" `
        -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($p.Dir | Split-Path -Leaf)" } else { $null })

    $p2 = New-RunPaths -Case 'TP-002-trailing-args-ignored'
    $r2 = Invoke-Sudoku -Exe $Exe -ArgList @($easy, 'ignored', 'extra', 'args') -OutFile $p2.Out -ErrFile $p2.Err
    $stdout2 = ConvertTo-NormalizedText (Get-Content -LiteralPath $p2.Out -Raw -ErrorAction SilentlyContinue)
    $pass2 = (-not $r2.TimedOut) -and $r2.ExitCode -eq 0 -and $stdout2 -eq $SEasyBlock
    Add-Check -Checks $Checks -Tp 'TP-002' -Case 'trailing-args-ignored' -State $(if ($pass2) { 'PASS' } else { 'FAIL' }) `
        -Expected 'identical output/exit to the bare-file-arg case' `
        -Observed "exit=$($r2.ExitCode) timedOut=$($r2.TimedOut)" `
        -Reason $(if (-not $pass2) { Get-FailureReason -Result $r2 -Fallback "see $($p2.Dir | Split-Path -Leaf)" } else { $null })

    $p3 = New-RunPaths -Case 'TP-002-file-arg-wins-over-stdin'
    $r3 = Invoke-Sudoku -Exe $Exe -ArgList @($easy) -StdinFile $FixturePaths['P-UNSOLVABLE'] -OutFile $p3.Out -ErrFile $p3.Err
    $stdout3 = ConvertTo-NormalizedText (Get-Content -LiteralPath $p3.Out -Raw -ErrorAction SilentlyContinue)
    $pass3 = (-not $r3.TimedOut) -and $r3.ExitCode -eq 0 -and $stdout3 -eq $SEasyBlock
    Add-Check -Checks $Checks -Tp 'TP-002' -Case 'file-arg-wins-over-stdin' -State $(if ($pass3) { 'PASS' } else { 'FAIL' }) `
        -Expected 'the file argument wins: stdout = S-EASY block, exit 0' `
        -Observed "exit=$($r3.ExitCode) timedOut=$($r3.TimedOut)" `
        -Reason $(if (-not $pass3) { Get-FailureReason -Result $r3 -Fallback "see $($p3.Dir | Split-Path -Leaf)" } else { $null })
}

# --- TP-003 - stdin fallback. ---
Invoke-Section -Name 'TP-003' -Body {
    $p = New-RunPaths -Case 'TP-003-stdin-fallback'
    $r = Invoke-Sudoku -Exe $Exe -ArgList @() -StdinFile $FixturePaths['P-EASY'] -OutFile $p.Out -ErrFile $p.Err
    $stdout = ConvertTo-NormalizedText (Get-Content -LiteralPath $p.Out -Raw -ErrorAction SilentlyContinue)
    $pass = (-not $r.TimedOut) -and $r.ExitCode -eq 0 -and $stdout -eq $SEasyBlock
    Add-Check -Checks $Checks -Tp 'TP-003' -Case 'stdin-fallback' -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
        -Expected 'no arguments, P-EASY on stdin -> S-EASY block, exit 0' `
        -Observed "exit=$($r.ExitCode) timedOut=$($r.TimedOut)" `
        -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($p.Dir | Split-Path -Leaf)" } else { $null })
}

# --- TP-009 - unreadable file argument. ---
Invoke-Section -Name 'TP-009' -Body {
    $missing = Join-Path $RunsDir 'TP-009-missing/does_not_exist.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $missing) | Out-Null
    if (Test-Path -LiteralPath $missing) { Remove-Item -LiteralPath $missing -Force }

    $p = New-RunPaths -Case 'TP-009-missing-file'
    $r = Invoke-Sudoku -Exe $Exe -ArgList @($missing) -OutFile $p.Out -ErrFile $p.Err
    $pass = (-not $r.TimedOut) -and $r.ExitCode -eq 1 -and $r.StdoutBytes -eq 0 -and $r.StderrBytes -gt 0
    Add-Check -Checks $Checks -Tp 'TP-009' -Case 'missing-file' -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
        -Expected 'stdout empty, stderr names the path, exit 1' `
        -Observed "exit=$($r.ExitCode) stdoutBytes=$($r.StdoutBytes) stderrBytes=$($r.StderrBytes)" `
        -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($p.Dir | Split-Path -Leaf)" } else { $null })

    $dirArg = Join-Path $RunsDir 'TP-009-directory-arg'
    New-Item -ItemType Directory -Force -Path $dirArg | Out-Null
    $p2 = New-RunPaths -Case 'TP-009-existing-directory'
    $r2 = Invoke-Sudoku -Exe $Exe -ArgList @($dirArg) -OutFile $p2.Out -ErrFile $p2.Err
    $pass2 = (-not $r2.TimedOut) -and $r2.ExitCode -eq 1 -and $r2.StdoutBytes -eq 0 -and $r2.StderrBytes -gt 0
    Add-Check -Checks $Checks -Tp 'TP-009' -Case 'existing-directory' -State $(if ($pass2) { 'PASS' } else { 'FAIL' }) `
        -Expected 'stdout empty, stderr names the path, exit 1' `
        -Observed "exit=$($r2.ExitCode) stdoutBytes=$($r2.StdoutBytes) stderrBytes=$($r2.StderrBytes)" `
        -Reason $(if (-not $pass2) { Get-FailureReason -Result $r2 -Fallback "see $($p2.Dir | Split-Path -Leaf)" } else { $null })
}

# --- TP-400/401/402/403/405/406 - output format, over the TP-300/405 fixture classes. ---
$FixtureClassRuns = @{}
Invoke-Section -Name 'TP-400' -Body {
    $p = New-RunPaths -Case 'TP-400-easy'
    $r = Invoke-Sudoku -Exe $Exe -ArgList @($FixturePaths['P-EASY']) -OutFile $p.Out -ErrFile $p.Err
    $FixtureClassRuns['Solved'] = @{ Paths = $p; Result = $r; ExpectedExit = 0 }
    $stdout = ConvertTo-NormalizedText (Get-Content -LiteralPath $p.Out -Raw -ErrorAction SilentlyContinue)
    $pass = (-not $r.TimedOut) -and $r.ExitCode -eq 0 -and $stdout -eq $SEasyBlock
    Add-Check -Checks $Checks -Tp 'TP-400' -Case 'grid-format-easy' -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
        -Expected 'stdout byte-for-byte equal (after CRLF normalisation) to the S-EASY §6.2 block' `
        -Observed "exit=$($r.ExitCode) timedOut=$($r.TimedOut) stdoutBytes=$($r.StdoutBytes)" `
        -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($p.Dir | Split-Path -Leaf)" } else { $null })
}

Invoke-Section -Name 'TP-401' -Body {
    $p = New-RunPaths -Case 'TP-401-nonunique'
    $r = Invoke-Sudoku -Exe $Exe -ArgList @($FixturePaths['P-NONUNIQUE']) -OutFile $p.Out -ErrFile $p.Err
    $FixtureClassRuns['SolvedNotUnique'] = @{ Paths = $p; Result = $r; ExpectedExit = 0 }
    $stdout = ConvertTo-NormalizedText (Get-Content -LiteralPath $p.Out -Raw -ErrorAction SilentlyContinue)
    $lines = $stdout -split "`n"
    $shape = Test-GridBlockShape -Lines $lines
    $note = $lines.Count -gt 13 -and ($lines[13..($lines.Count - 1)] -join "`n") -match '(?i)more than one solution'
    $pass = (-not $r.TimedOut) -and $r.ExitCode -eq 0 -and $r.StderrBytes -eq 0 -and $shape.Ok -and $note
    Add-Check -Checks $Checks -Tp 'TP-401' -Case 'nonunique-note' -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
        -Expected '13-line grid (either S-NONUNIQUE-A or -B) followed by the not-unique note, stderr empty, exit 0' `
        -Observed "exit=$($r.ExitCode) shape=$($shape.Detail) note=$note" `
        -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($p.Dir | Split-Path -Leaf)" } else { $null })
}

Invoke-Section -Name 'TP-402' -Body {
    $p = New-RunPaths -Case 'TP-402-unsolvable'
    $r = Invoke-Sudoku -Exe $Exe -ArgList @($FixturePaths['P-UNSOLVABLE']) -OutFile $p.Out -ErrFile $p.Err
    $FixtureClassRuns['NoSolution'] = @{ Paths = $p; Result = $r; ExpectedExit = 2 }
    $stdout = (Get-Content -LiteralPath $p.Out -Raw -ErrorAction SilentlyContinue)
    $normalized = ConvertTo-NormalizedText $stdout
    $lines = @($normalized -split "`n" | Where-Object { $_.Length -gt 0 })
    $pass = (-not $r.TimedOut) -and $r.ExitCode -eq 2 -and $lines.Count -eq 1 -and $lines[0] -notmatch '\+---' -and $lines[0] -match '(?i)no solution'
    Add-Check -Checks $Checks -Tp 'TP-402' -Case 'no-solution-statement' -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
        -Expected 'a single stdout line stating no solution, no grid, exit 2' `
        -Observed "exit=$($r.ExitCode) lineCount=$($lines.Count) firstLine='$($lines[0])'" `
        -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($p.Dir | Split-Path -Leaf)" } else { $null })
}

Invoke-Section -Name 'TP-403' -Body {
    $cases = @(
        @{ Name = 'badchar'; Path = $FixturePaths['P-BADCHAR'] },
        @{ Name = 'short'; Path = $FixturePaths['P-SHORT'] },
        @{ Name = 'contra-row'; Path = $FixturePaths['P-CONTRA-ROW'] }
    )
    foreach ($c in $cases) {
        $p = New-RunPaths -Case "TP-403-$($c.Name)"
        $r = Invoke-Sudoku -Exe $Exe -ArgList @($c.Path) -OutFile $p.Out -ErrFile $p.Err
        if ($c.Name -eq 'badchar') { $FixtureClassRuns['InvalidInput'] = @{ Paths = $p; Result = $r; ExpectedExit = 1 } }
        $pass = (-not $r.TimedOut) -and $r.ExitCode -eq 1 -and $r.StdoutBytes -eq 0 -and $r.StderrBytes -gt 0
        Add-Check -Checks $Checks -Tp 'TP-403' -Case $c.Name -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
            -Expected 'stdout zero bytes, diagnostic on stderr, exit 1' `
            -Observed "exit=$($r.ExitCode) stdoutBytes=$($r.StdoutBytes) stderrBytes=$($r.StderrBytes)" `
            -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($p.Dir | Split-Path -Leaf)" } else { $null })
    }
}

# TP-004..008 (aborted case) need the RTVM-507 hook's interactive protocol,
# which this script does not yet drive - see the P4 section below. TP-405's
# fifth fixture class (Aborted / exit 3) is therefore NOT-RUN, not a made-up
# pass; TP-406 below only covers the four fixture classes actually run.
Invoke-Section -Name 'TP-405' -Body {
    $expectedByClass = @{ Solved = 0; SolvedNotUnique = 0; InvalidInput = 1; NoSolution = 2 }
    $allMatch = $true
    $detail = New-Object System.Collections.Generic.List[string]
    foreach ($class in $expectedByClass.Keys) {
        if (-not $FixtureClassRuns.ContainsKey($class)) { $allMatch = $false; $detail.Add("$class not run"); continue }
        $actual = $FixtureClassRuns[$class].Result.ExitCode
        $expected = $expectedByClass[$class]
        if ($actual -ne $expected) { $allMatch = $false }
        $detail.Add("$class expected=$expected actual=$actual")
    }
    Add-Check -Checks $Checks -Tp 'TP-405' -Case 'exit-codes-four-fixture-classes' -State $(if ($allMatch) { 'PASS' } else { 'FAIL' }) `
        -Expected '0, 0, 1, 2 for Solved/SolvedNotUnique/InvalidInput/NoSolution' `
        -Observed ($detail -join '; ')
    Add-Check -Checks $Checks -Tp 'TP-405' -Case 'aborted-exit-code' -State 'NOT-RUN' `
        -Reason 'exercising exit code 3 needs the RTVM-507 hook + stop-response protocol - see the P4 hook-probe section'
}

Invoke-Section -Name 'TP-406' -Body {
    $forbidden = @('Still working', 'abandoned', 'r1c1', 'Error', 'could not')
    foreach ($class in $FixtureClassRuns.Keys) {
        $run = $FixtureClassRuns[$class]

        # A run that never reached its expected exit code (a launch
        # failure, a crash, a hang) produces empty/irrelevant stdout that
        # trivially "contains none of" the forbidden substrings - that read
        # as a false PASS here (Test Engineer, issue #23, 2026-08-13:
        # TP-406 marked PASS for a run that never executed the product at
        # all). Absence of evidence is NOT-RUN, never PASS-by-emptiness.
        $launchedAsExpected = ($run.Result.ExitCode -ne -1) -and ($run.Result.ExitCode -eq $run.ExpectedExit)
        if (-not $launchedAsExpected) {
            Add-Check -Checks $Checks -Tp 'TP-406' -Case "stream-separation-$class" -State 'NOT-RUN' `
                -Reason (Get-FailureReason -Result $run.Result -Fallback "underlying $class run did not reach its expected exit code ($($run.ExpectedExit); observed $($run.Result.ExitCode)) - stdout content is not evidence of stream separation for a run that didn't happen as expected")
            continue
        }

        $stdout = (Get-Content -LiteralPath $run.Paths.Out -Raw -ErrorAction SilentlyContinue)
        if (-not $stdout) { $stdout = '' }
        $hit = $forbidden | Where-Object { $stdout.Contains($_) }
        $pass = $hit.Count -eq 0
        Add-Check -Checks $Checks -Tp 'TP-406' -Case "stream-separation-$class" -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
            -Expected 'stdout contains none of: Still working, abandoned, r1c1, Error, could not' `
            -Observed $(if ($pass) { 'clean' } else { "forbidden substrings present: $($hit -join ', ')" })
    }
}

# --- TP-505 - robustness corpus (>= 25 inputs). ---
Invoke-Section -Name 'TP-505' -Body {
    $work = Join-Path $RunsDir 'TP-505'
    New-Item -ItemType Directory -Force -Path $work | Out-Null

    $entries = New-Object System.Collections.Generic.List[hashtable]

    $emptyFile = Join-Path $work 'empty.txt'
    Write-Utf8NoBom -Path $emptyFile -Content ''
    $entries.Add(@{ Name = 'empty-input-zero-bytes'; Path = $emptyFile })

    $newlineFile = Join-Path $work 'single-newline.txt'
    Write-Utf8NoBom -Path $newlineFile -Content "`n"
    $entries.Add(@{ Name = 'single-newline'; Path = $newlineFile })

    $tenKFile = Join-Path $work 'ten-thousand-lines.txt'
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt 10000; $i++) { [void]$sb.Append("123456789`n") }
    Write-Utf8NoBom -Path $tenKFile -Content $sb.ToString()
    $entries.Add(@{ Name = 'ten-thousand-lines-digits'; Path = $tenKFile })

    $oneMbFile = Join-Path $work 'one-mb-single-line.txt'
    $unit = '1234567890'
    $repeats = [Math]::Ceiling(1048576 / $unit.Length)
    $oneMb = ($unit * $repeats).Substring(0, 1048576)
    Write-Utf8NoBom -Path $oneMbFile -Content $oneMb
    $entries.Add(@{ Name = 'one-mb-single-line'; Path = $oneMbFile })

    $easyText = (($Fixtures['P-EASY'] -join "`n") + "`n")

    $nulFile = Join-Path $work 'nul-byte.txt'
    $easyBytes = [System.Text.Encoding]::UTF8.GetBytes($easyText)
    $withNul = $easyBytes[0..4] + [byte]0 + $easyBytes[5..($easyBytes.Length - 1)]
    [System.IO.File]::WriteAllBytes($nulFile, $withNul)
    $entries.Add(@{ Name = 'embedded-nul-byte'; Path = $nulFile })

    $bomFile = Join-Path $work 'utf8-bom.txt'
    $bomBytes = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes($easyText)
    [System.IO.File]::WriteAllBytes($bomFile, $bomBytes)
    $entries.Add(@{ Name = 'utf8-bom'; Path = $bomFile })

    $fullWidthFile = Join-Path $work 'fullwidth-digits.txt'
    Write-Utf8NoBom -Path $fullWidthFile -Content (ConvertTo-FullWidthDigits $easyText)
    $entries.Add(@{ Name = 'fullwidth-digits-nonascii'; Path = $fullWidthFile })

    $binaryFile = Join-Path $work 'binary-from-exe.dat'
    $exeBytes = [System.IO.File]::ReadAllBytes($Exe)
    $take = [Math]::Min(4096, $exeBytes.Length) - 1
    [System.IO.File]::WriteAllBytes($binaryFile, $exeBytes[0..$take])
    $entries.Add(@{ Name = 'binary-content-from-exe'; Path = $binaryFile })

    foreach ($name in $Fixtures.Keys) {
        $entries.Add(@{ Name = "fixture-$name"; Path = $FixturePaths[$name] })
    }

    $dirArg = Join-Path $work 'a-directory'
    New-Item -ItemType Directory -Force -Path $dirArg | Out-Null
    $entries.Add(@{ Name = 'directory-argument'; Path = $dirArg })

    $lockedFile = Join-Path $work 'locked.txt'
    Write-Utf8NoBom -Path $lockedFile -Content $easyText
    $entries.Add(@{ Name = 'locked-file-argument'; Path = $lockedFile; Lock = $true })

    $exitCodesSeen = New-Object System.Collections.Generic.List[int]
    $allOk = $true

    foreach ($entry in $entries) {
        $caseDir = Join-Path $work ($entry.Name -replace '[^a-zA-Z0-9\-]', '_')
        New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
        $outFile = Join-Path $caseDir 'stdout.txt'
        $errFile = Join-Path $caseDir 'stderr.txt'

        $lockHandle = $null
        if ($entry.Lock) {
            try {
                $lockHandle = [System.IO.File]::Open($entry.Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            }
            catch {
                # Couldn't even acquire the lock ourselves - not fatal to the
                # corpus, just means this one case degrades to an ordinary
                # readable file.
            }
        }

        try {
            $r = Invoke-Sudoku -Exe $Exe -ArgList @($entry.Path) -OutFile $outFile -ErrFile $errFile -TimeoutSec 60
        }
        finally {
            if ($lockHandle) { $lockHandle.Close() }
        }

        $stderrText = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
        if (-not $stderrText) { $stderrText = '' }
        $stdoutText = (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue)
        if (-not $stdoutText) { $stdoutText = '' }

        $exitInRange = (-not $r.TimedOut) -and ($r.ExitCode -in 0, 1, 2, 3)
        $noCrashText = -not (Test-ContainsCrashText ($stdoutText + $stderrText))
        $pass = $exitInRange -and $noCrashText

        if (-not $r.TimedOut) { $exitCodesSeen.Add($r.ExitCode) }
        if (-not $pass) { $allOk = $false }

        Add-Check -Checks $Checks -Tp 'TP-505' -Case $entry.Name -State $(if ($pass) { 'PASS' } else { 'FAIL' }) `
            -Expected 'process exits within 60s, exit code in {0,1,2,3}, no unhandled-exception text' `
            -Observed "exit=$($r.ExitCode) timedOut=$($r.TimedOut) elapsedMs=$([math]::Round($r.ElapsedMs,1)) crashText=$(-not $noCrashText)" `
            -Reason $(if (-not $pass) { Get-FailureReason -Result $r -Fallback "see $($caseDir | Split-Path -Leaf)" } else { $null })
    }

    Add-Check -Checks $Checks -Tp 'TP-405' -Case 'corpus-exit-code-range' -State $(if ($allOk) { 'PASS' } else { 'FAIL' }) `
        -Expected "every one of $($entries.Count) TP-505 corpus runs exits in {0,1,2,3}" `
        -Observed "$($entries.Count) entries run; distinct exit codes seen: $((($exitCodesSeen | Sort-Object -Unique) -join ', '))"
}

# Diagnostic only, not a TP - see the doc comment on Invoke-ConPtyDiagnostics.
# Written to conpty-diag.txt in the artifact so a "the real probes saw
# nothing" result below can be bisected without a second Windows run.
Invoke-Section -Name 'ConPTY-diag' -Body {
    Invoke-ConPtyDiagnostics -Exe $Exe -FixtureFile $FixturePaths['P-EASY'] -EvidenceDir $EvidenceDir
}

# ===========================================================================
# P4a - TP-004/005/006 under a real ConPTY (issue #25, docs/RTVM.md §9.4
# A-4). Everything else in this script drives $Exe over a pipe or a file
# (Invoke-Sudoku, Common.ps1) - StdinChannel's `Console` `StdinKind` branch
# (GetFileType==console, PeekConsoleInput, ReadConsoleA) is never entered
# that way. This section puts a genuine Windows console handle in front of
# it instead, via ConPty.ps1's CreatePseudoConsole-based driver.
#
# TP-007/TP-008 and TP-507's active-hook clause are deliberately left in the
# P4b NOT-RUN set below, unchanged - the issue that added this section
# scoped the ConPTY attempt to TP-004/005/006 specifically (RTVM-007/008
# already have hand-run pipe/file/Null evidence that doesn't turn on which
# StdinKind was used; TP-507's hook-is-active clause is a property of the
# environment variable, not of the console, so Test-DiagHookActive's
# existing pipe-based probe already speaks to it as far as this script
# goes).
Invoke-Section -Name 'TP-004,TP-006' -Body {
    $r = Invoke-ConPty004006Probe -Exe $Exe -FixtureFile $FixturePaths['P-EASY'] -EvidenceDir $EvidenceDir

    if (-not $r.Started) {
        # The honest negative result the issue asks for: precisely what was
        # tried (CreatePseudoConsole + CreateProcessW under EXTENDED_STARTUPINFO_PRESENT)
        # and precisely what stopped it, not "consoles are hard".
        foreach ($case in @('prompt-content-and-timing', 'nothing-on-stdout-at-first-prompt')) {
            Add-Check -Checks $Checks -Tp 'TP-004' -Case $case -State 'NOT-RUN' `
                -Reason "ConPTY session did not start: $($r.StartError)"
        }
        foreach ($case in @('four-scheduled-prompts-no-long-gap', 'still-running-past-45s', 'stop-response-exit-3')) {
            Add-Check -Checks $Checks -Tp 'TP-006' -Case $case -State 'NOT-RUN' `
                -Reason "ConPTY session did not start: $($r.StartError)"
        }
        return
    }

    $gotFirstPrompt = $r.PromptTimestampsSec.Count -ge 1
    $contentOk = $gotFirstPrompt -and
        $r.FirstPromptText -match 'Still working \(\d+s elapsed\)\.' -and
        $r.FirstPromptText -match '(?i)stop' -and
        $r.FirstPromptText -match '(?i)no response'
    Add-Check -Checks $Checks -Tp 'TP-004' -Case 'prompt-content-and-timing' `
        -State $(if ($contentOk) { 'PASS' } else { 'FAIL' }) `
        -Expected 'a line matching "Still working (Ns elapsed)." plus the stop gesture and "no response needed", visible at the first prompt over a real console handle' `
        -Observed "gotFirstPrompt=$gotFirstPrompt promptSeconds=$(if ($gotFirstPrompt) { $r.PromptTimestampsSec[0] } else { 'n/a' }) text='$($r.FirstPromptText)'" `
        -Reason $(if (-not $contentOk) { "see $($r.RawOutputPath | Split-Path -Leaf) in the artifact ($($r.RawOutputPath))" } else { $null })

    # $Exe runs under a cmd.exe intermediary attached to the pseudoconsole
    # (ConPty.ps1's Start(), "sixth Windows round"): stdin is still the
    # genuine console handle, but stdout/stderr are cmd's own ordinary file
    # redirects, independently readable - not inferred from one merged VT
    # transcript the way rounds 1-5 had to. $r.StdoutBytesAtFirstPrompt is a
    # real byte count on $r.StdoutPath at the moment the first prompt
    # appeared on $r.StderrPath.
    $noGridYet = $gotFirstPrompt -and (-not $r.GridSeenBeforeFirstPrompt)
    Add-Check -Checks $Checks -Tp 'TP-004' -Case 'nothing-on-stdout-at-first-prompt' `
        -State $(if ($noGridYet) { 'PASS' } else { 'FAIL' }) `
        -Expected 'stdout.txt is still 0 bytes at the moment the first prompt appears on stderr.txt' `
        -Observed "stdoutBytesAtFirstPrompt=$($r.StdoutBytesAtFirstPrompt)" `
        -Reason $(if (-not $noGridYet) { "see $($r.StdoutPath | Split-Path -Leaf)/$($r.StderrPath | Split-Path -Leaf) in the artifact: $($r.StdoutPath)" } else { $null })

    $fourPrompts = $r.PromptTimestampsSec.Count -ge 4
    $gapOk = ($null -eq $r.MaxGapAfterFirstPromptSec) -or ($r.MaxGapAfterFirstPromptSec -le 11.0)
    Add-Check -Checks $Checks -Tp 'TP-006' -Case 'four-scheduled-prompts-no-long-gap' `
        -State $(if ($fourPrompts -and $gapOk) { 'PASS' } else { 'FAIL' }) `
        -Expected 'prompts at ~15/25/35/45s (4 total) and no gap between them over 11.0s (§7 I-12)' `
        -Observed "timestampsSec=$($r.PromptTimestampsSec -join ', ') maxGapSec=$($r.MaxGapAfterFirstPromptSec)" `
        -Reason $(if (-not ($fourPrompts -and $gapOk)) { "see $($r.RawOutputPath | Split-Path -Leaf) in the artifact: $($r.RawOutputPath)" } else { $null })

    Add-Check -Checks $Checks -Tp 'TP-006' -Case 'still-running-past-45s' `
        -State $(if ($r.StillRunningAfterFourth) { 'PASS' } else { 'FAIL' }) `
        -Expected 'process still running (not exited) once the fourth prompt has appeared' `
        -Observed "stillRunningAfterFourth=$($r.StillRunningAfterFourth)"

    $stopOk = $r.StopExitCode -eq 3
    Add-Check -Checks $Checks -Tp 'TP-006' -Case 'stop-response-exit-3' `
        -State $(if ($stopOk) { 'PASS' } else { 'FAIL' }) `
        -Expected 'sending the stop response over the console input pipe ends the process with exit code 3' `
        -Observed "stopExitCode=$($r.StopExitCode) stopLatencyMs=$($r.StopLatencyMs)" `
        -Reason $(if (-not $stopOk) { "see $($r.RawOutputPath | Split-Path -Leaf) in the artifact: $($r.RawOutputPath)" } else { $null })
}

# ===========================================================================
# P4b - TP-005, a dedicated (shorter) ConPTY session: the stop response has
# to land at the *first* prompt specifically (TP-005's own wording, as
# opposed to TP-006's fourth), and the 1.0s response-to-exit bound is its
# own assertion.
# ===========================================================================
Invoke-Section -Name 'TP-005' -Body {
    $r = Invoke-ConPty005Probe -Exe $Exe -FixtureFile $FixturePaths['P-EASY'] -EvidenceDir $EvidenceDir

    if (-not $r.Started) {
        foreach ($case in @('exit-3-within-1s', 'abandonment-message-and-empty-stdout')) {
            Add-Check -Checks $Checks -Tp 'TP-005' -Case $case -State 'NOT-RUN' `
                -Reason "ConPTY session did not start: $($r.StartError)"
        }
        return
    }

    if ($null -eq $r.FirstPromptSeconds) {
        foreach ($case in @('exit-3-within-1s', 'abandonment-message-and-empty-stdout')) {
            Add-Check -Checks $Checks -Tp 'TP-005' -Case $case -State 'FAIL' `
                -Reason "no prompt appeared within the 25s ceiling - see $($r.RawOutputPath | Split-Path -Leaf): $($r.RawOutputPath)"
        }
        return
    }

    $latencyOk = ($null -ne $r.StopLatencyMs) -and ($r.StopLatencyMs -lt 1000)
    $exitOk = $r.StopExitCode -eq 3
    Add-Check -Checks $Checks -Tp 'TP-005' -Case 'exit-3-within-1s' `
        -State $(if ($latencyOk -and $exitOk) { 'PASS' } else { 'FAIL' }) `
        -Expected 'responding at the first prompt over a real console handle ends the process with exit 3 within 1.0s (RTVM-203)' `
        -Observed "firstPromptSeconds=$($r.FirstPromptSeconds) stopExitCode=$($r.StopExitCode) stopLatencyMs=$($r.StopLatencyMs)" `
        -Reason $(if (-not ($latencyOk -and $exitOk)) { "see $($r.RawOutputPath | Split-Path -Leaf) in the artifact: $($r.RawOutputPath)" } else { $null })

    $contentOk = $r.AbandonedTextSeen -and $r.StdoutStayedEmpty
    Add-Check -Checks $Checks -Tp 'TP-005' -Case 'abandonment-message-and-empty-stdout' `
        -State $(if ($contentOk) { 'PASS' } else { 'FAIL' }) `
        -Expected 'stderr.txt gains a line containing "abandoned at"; stdout.txt stays 0 bytes throughout (RTVM-404)' `
        -Observed "abandonedTextSeen=$($r.AbandonedTextSeen) stdoutStayedEmpty=$($r.StdoutStayedEmpty)" `
        -Reason $(if (-not $contentOk) { "see $($r.StdoutPath | Split-Path -Leaf)/$($r.StderrPath | Split-Path -Leaf) in the artifact: $($r.StdoutPath)" } else { $null })
}

# ===========================================================================
# P4c - the remaining NOT-RUN set, with a measured reason rather than an
# assumed one. TP-004/005/006 moved to the sections above (issue #25);
# TP-007/008 and TP-507's active-hook clause are unaffected by this issue -
# see the comment on the P4a section for why.
# ===========================================================================
Invoke-Section -Name 'TP-007,TP-008,TP-507' -Body {
    $probe = Test-DiagHookActive -Exe $Exe -FixtureFile $FixturePaths['P-EASY'] -EvidenceDir $EvidenceDir
    $rows = @(
        @{ Tp = 'TP-007'; Case = 'lapsed-prompt-abandoned' },
        @{ Tp = 'TP-008'; Case = 'non-interactive-invocation' },
        @{ Tp = 'TP-507'; Case = 'active-hook-demonstration' }
    )
    foreach ($row in $rows) {
        Add-Check -Checks $Checks -Tp $row.Tp -Case $row.Case -State 'NOT-RUN' -Reason $probe.Reason
    }
}

}
catch {
    Add-Check -Checks $Checks -Tp 'script' -Case 'top-level' -State 'FAIL' `
        -Reason "unhandled exception outside any section: $($_.Exception.Message)" `
        -Observed $_.ScriptStackTrace
}
finally {
    Write-EvidenceJson -Path (Join-Path $EvidenceDir 'runtime-procedures.json') -Checks $Checks -Sha $Sha -Machine $Machine
}

exit 0

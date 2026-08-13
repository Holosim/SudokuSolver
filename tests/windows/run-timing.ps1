#requires -Version 5.1
<#
.SYNOPSIS
    Windows evidence for the RTVM-500 performance budget (TP-500) and the
    prompt-timing set (TP-501..504).

.DESCRIPTION
    Invoked by .github/workflows/windows-verification.yml three times per
    run (W-7): once per sample. Absent = NOT-RUN in the workflow summary,
    never a pass (V-6). Lives here, not in the workflow, so it can be
    revised without a workflows-permission round trip (W-10, V-10).

    Full specification: issue #23, Test Engineer comment "Specification —
    the two scripts" (2026-08-13), tests/windows/run-timing.ps1 section,
    contract C1-C7.

    W-7: no retries, no outlier discarding. Every sample this script has
    ever produced for this job is kept and re-merged into timing.json on
    every invocation - "do not overwrite" (C2). A tolerance breach is
    reported with all samples intact, never hidden by a retry.

.PARAMETER Exe
    Path to the built SudokuSolver.exe. TP-500 specifies the Release
    build; this script asserts $Exe resolves under \x64\Release\ and
    records the result rather than silently trusting the caller.

.PARAMETER EvidenceDir
    Directory the workflow publishes as the windows-evidence-<sha>
    artifact.

.PARAMETER Sample
    Which of the (W-7) three invocations this is. Used only to name
    timing-sample-<N>.json; the merge step re-reads every
    timing-sample-*.json present, not just this one.
#>
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$EvidenceDir,
    [int]$Sample = 1
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Fixtures.ps1')

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Checks = New-CheckList
$Machine = Read-MachineBlock -EvidenceDir $EvidenceDir
$Sha = Get-CommitSha -RepoRoot $RepoRoot
$SamplesDir = Join-Path $RepoRoot 'samples'
$RunsDir = Join-Path $EvidenceDir "timing-runs\sample-$Sample"

try {

    # --- Release-build sanity check (TP-500 specifies Release|x64). ---
    $isRelease = $Exe -match '(?i)\\x64\\Release\\'
    Add-Check -Checks $Checks -Tp 'TP-500' -Case 'release-build-check' -State $(if ($isRelease) { 'PASS' } else { 'FAIL' }) `
        -Expected '$Exe resolves under \x64\Release\' `
        -Observed $Exe `
        -Reason $(if (-not $isRelease) { 'a Debug binary would quietly invalidate every timing figure below' } else { $null })

    # --- Resolve the three timing fixtures, preferring samples/ (RTVM-907). ---
    $fixtureNames = @{
        'easy'       = @{ Tp = 'P-EASY'; Sample = 'easy.txt' }
        'hard17'     = @{ Tp = 'P-HARD17'; Sample = 'hard17.txt' }
        'unsolvable' = @{ Tp = 'P-UNSOLVABLE'; Sample = 'unsolvable.txt' }
    }
    $Fixtures = Get-Fixtures
    $fixtureDir = Join-Path $EvidenceDir 'fixtures'
    $publishedFixtures = Publish-Fixtures -Fixtures $Fixtures -Dir $fixtureDir -SamplesDir $SamplesDir

    $resolvedFixtures = @{}
    foreach ($key in $fixtureNames.Keys) {
        $exeDirCandidate = Join-Path (Split-Path -Parent $Exe) $fixtureNames[$key].Sample
        if (Test-Path -LiteralPath $exeDirCandidate) {
            $resolvedFixtures[$key] = $exeDirCandidate
        }
        else {
            $resolvedFixtures[$key] = $publishedFixtures[$fixtureNames[$key].Tp]
        }
    }

    # --- TP-500: 10 consecutive runs per fixture, min/median/max, no retries. ---
    foreach ($key in @('easy', 'hard17', 'unsolvable')) {
        $fixturePath = $resolvedFixtures[$key]
        $runsDirForFixture = Join-Path $RunsDir $key
        New-Item -ItemType Directory -Force -Path $runsDirForFixture | Out-Null

        $timingsMs = New-Object System.Collections.Generic.List[double]
        $exitCodes = New-Object System.Collections.Generic.List[int]
        $anyTimedOut = $false

        for ($i = 1; $i -le 10; $i++) {
            $outFile = Join-Path $runsDirForFixture "run-$i-stdout.txt"
            $errFile = Join-Path $runsDirForFixture "run-$i-stderr.txt"
            $r = Invoke-Sudoku -Exe $Exe -ArgList @($fixturePath) -OutFile $outFile -ErrFile $errFile -TimeoutSec 30
            if ($r.TimedOut) { $anyTimedOut = $true }
            else {
                $timingsMs.Add($r.ElapsedMs)
                $exitCodes.Add($r.ExitCode)
            }
        }

        if ($timingsMs.Count -eq 0) {
            Add-Check -Checks $Checks -Tp 'TP-500' -Case $key -State 'FAIL' `
                -Reason "all 10 runs timed out at the 30s per-run ceiling - see $runsDirForFixture in the artifact"
            continue
        }

        $sorted = $timingsMs | Sort-Object
        $min = $sorted[0]
        $max = $sorted[$sorted.Count - 1]
        $mid = [Math]::Floor(($sorted.Count - 1) / 2)
        $median = if ($sorted.Count % 2 -eq 1) { $sorted[$mid] } else { ($sorted[$mid] + $sorted[$mid + 1]) / 2 }

        $withinBudget = ($max -le 10000) -and (-not $anyTimedOut) -and ($timingsMs.Count -eq 10)
        Add-Check -Checks $Checks -Tp 'TP-500' -Case $key -State $(if ($withinBudget) { 'PASS' } else { 'FAIL' }) `
            -Expected 'worst of 10 consecutive runs under 10.0s' `
            -Observed ([ordered]@{
                    runs      = $timingsMs.Count
                    minMs     = [math]::Round($min, 1)
                    medianMs  = [math]::Round($median, 1)
                    maxMs     = [math]::Round($max, 1)
                    allMs     = ($timingsMs | ForEach-Object { [math]::Round($_, 1) })
                    exitCodes = $exitCodes
                    anyTimedOut = $anyTimedOut
                } | ConvertTo-Json -Compress) `
            -Reason $(if (-not $withinBudget) { 'reported as an observation against the 10.0s ceiling, all samples intact - no retry (W-7)' } else { $null })
    }

    # --- TP-501..504: NOT-RUN, same hook probe as run-procedures.ps1's P4. ---
    $probe = Test-DiagHookActive -Exe $Exe -FixtureFile $resolvedFixtures['easy'] -EvidenceDir $EvidenceDir
    foreach ($row in @(
            @{ Tp = 'TP-501'; Case = 'first-prompt-timing' },
            @{ Tp = 'TP-502'; Case = 'repeat-interval' },
            @{ Tp = 'TP-503'; Case = 'solve-continues-during-prompt' },
            @{ Tp = 'TP-504'; Case = 'never-silent' }
        )) {
        Add-Check -Checks $Checks -Tp $row.Tp -Case $row.Case -State 'NOT-RUN' -Reason $probe.Reason
    }
}
catch {
    Add-Check -Checks $Checks -Tp 'script' -Case 'top-level' -State 'FAIL' `
        -Reason "unhandled exception outside any section: $($_.Exception.Message)" `
        -Observed $_.ScriptStackTrace
}
finally {
    # Per-sample raw evidence (kept forever - never overwritten by a later
    # sample) plus the merged timing.json re-derived from every
    # timing-sample-*.json present so far in this job (C2: "do not
    # overwrite", W-7: all samples reported).
    $samplePath = Join-Path $EvidenceDir "timing-sample-$Sample.json"
    Write-EvidenceJson -Path $samplePath -Checks $Checks -Sha $Sha -Machine $Machine

    try {
        $allSampleChecks = New-Object System.Collections.Generic.List[object]
        Get-ChildItem -Path $EvidenceDir -Filter 'timing-sample-*.json' -ErrorAction SilentlyContinue |
            Sort-Object { [int]($_.BaseName -replace '\D', '') } | ForEach-Object {
                try {
                    $doc = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
                    foreach ($c in $doc.checks) {
                        $allSampleChecks.Add([ordered]@{
                            tp       = $c.tp
                            case     = $c.case
                            state    = $c.state
                            expected = $c.expected
                            observed = $c.observed
                            reason   = $c.reason
                            fromFile = $_.Name
                        })
                    }
                }
                catch {
                    $allSampleChecks.Add([ordered]@{
                        tp = 'script'; case = 'merge'; state = 'FAIL'
                        reason = "could not parse $($_.Name): $($_.Exception.Message)"
                        expected = $null; observed = $null
                    })
                }
            }
        Write-EvidenceJson -Path (Join-Path $EvidenceDir 'timing.json') -Checks $allSampleChecks -Sha $Sha -Machine $Machine
    }
    catch {
        # The per-sample file above already landed; a merge failure must not
        # take that down with it (C1).
    }
}

exit 0

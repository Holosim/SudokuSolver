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

    TP-501..503 stay NOT-RUN here (see the hook-probe loop below) — they
    assert the *interactive* stop/reply protocol, which needs a real
    console (#25, the ConPTY spike, still open). TP-504 needs no reply at
    all (RTVM-006/008: an unanswered prompt just lapses, a non-interactive
    invocation is never blocked), so it's driven for real: issue #19,
    docs/RTVM.md §7 I-12.

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
    # ExpectedExit matters for $withinBudget below: a run that fails to
    # launch (or otherwise doesn't reach the exit code RTVM-400/402 define
    # for this fixture class) times a launch failure, not the solver, and
    # must never read as a budget PASS (Test Engineer, issue #23,
    # 2026-08-13: TP-500 was reporting PASS at 0.4-21.2ms against a corpus
    # of runs that all failed to launch).
    # 'badchar' is only consumed by TP-504 below (TP-500's own loop still
    # names its three keys explicitly), added here so it shares the same
    # resolution -> samples/, else a freshly-written fixture -> pass below.
    $fixtureNames = @{
        'easy'       = @{ Tp = 'P-EASY'; Sample = 'easy.txt'; ExpectedExit = 0 }
        'hard17'     = @{ Tp = 'P-HARD17'; Sample = 'hard17.txt'; ExpectedExit = 0 }
        'unsolvable' = @{ Tp = 'P-UNSOLVABLE'; Sample = 'unsolvable.txt'; ExpectedExit = 2 }
        'badchar'    = @{ Tp = 'P-BADCHAR'; Sample = 'malformed.txt'; ExpectedExit = 1 }
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
        $expectedExit = $fixtureNames[$key].ExpectedExit
        $runsDirForFixture = Join-Path $RunsDir $key
        New-Item -ItemType Directory -Force -Path $runsDirForFixture | Out-Null

        $timingsMs = New-Object System.Collections.Generic.List[double]
        $exitCodes = New-Object System.Collections.Generic.List[int]
        $launchErrors = New-Object System.Collections.Generic.List[string]
        $anyTimedOut = $false
        $anyWrongExit = $false

        for ($i = 1; $i -le 10; $i++) {
            $outFile = Join-Path $runsDirForFixture "run-$i-stdout.txt"
            $errFile = Join-Path $runsDirForFixture "run-$i-stderr.txt"
            $r = Invoke-Sudoku -Exe $Exe -ArgList @($fixturePath) -OutFile $outFile -ErrFile $errFile -TimeoutSec 30
            if ($r.TimedOut) { $anyTimedOut = $true }
            else {
                $timingsMs.Add($r.ElapsedMs)
                $exitCodes.Add($r.ExitCode)
                if ($r.ExitCode -ne $expectedExit) {
                    $anyWrongExit = $true
                    if ($r.LaunchError) { $launchErrors.Add($r.LaunchError) }
                }
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

        # A timing figure is only evidence about the 10.0s budget if the
        # process actually reached the exit code this fixture class is
        # defined to produce (RTVM-400/402) - otherwise the number being
        # measured is however long a launch failure or crash took, not a
        # solve (Test Engineer, issue #23, 2026-08-13).
        $withinBudget = ($max -le 10000) -and (-not $anyTimedOut) -and (-not $anyWrongExit) -and ($timingsMs.Count -eq 10)
        $reason = if ($anyWrongExit) {
            $detail = if ($launchErrors.Count -gt 0) { "; launch error(s): $(($launchErrors | Select-Object -Unique) -join '; ')" } else { '' }
            "not every run reached the expected exit code ($expectedExit) - a timing figure from a failed run is not evidence about the solve budget$detail"
        }
        elseif (-not $withinBudget) {
            'reported as an observation against the 10.0s ceiling, all samples intact - no retry (W-7)'
        }
        else { $null }
        Add-Check -Checks $Checks -Tp 'TP-500' -Case $key -State $(if ($withinBudget) { 'PASS' } else { 'FAIL' }) `
            -Expected "worst of 10 consecutive runs under 10.0s, every run exiting $expectedExit" `
            -Observed ([ordered]@{
                    runs        = $timingsMs.Count
                    minMs       = [math]::Round($min, 1)
                    medianMs    = [math]::Round($median, 1)
                    maxMs       = [math]::Round($max, 1)
                    allMs       = ($timingsMs | ForEach-Object { [math]::Round($_, 1) })
                    exitCodes   = $exitCodes
                    expectedExit = $expectedExit
                    anyTimedOut = $anyTimedOut
                    anyWrongExit = $anyWrongExit
                } | ConvertTo-Json -Compress) `
            -Reason $reason
    }

    # --- TP-501..503: still NOT-RUN. These assert the interactive
    # stop/reply protocol (TP-501/502 time prompts against a reply that is
    # never sent; TP-503 needs the RTVM-204 step count either side of a
    # prompt window), which #25's ConPTY spike hasn't landed yet. Kept on
    # the same hook probe run-procedures.ps1's P4 uses so the reason stays
    # measured, not assumed.
    $probe = Test-DiagHookActive -Exe $Exe -FixtureFile $resolvedFixtures['easy'] -EvidenceDir $EvidenceDir
    foreach ($row in @(
            @{ Tp = 'TP-501'; Case = 'first-prompt-timing' },
            @{ Tp = 'TP-502'; Case = 'repeat-interval' },
            @{ Tp = 'TP-503'; Case = 'solve-continues-during-prompt' }
        )) {
        Add-Check -Checks $Checks -Tp $row.Tp -Case $row.Case -State 'NOT-RUN' -Reason $probe.Reason
    }

    # --- TP-504: never silent, piecewise bound (docs/RTVM.md §7 I-12). ---
    # Unlike TP-501..503, this needs no reply at all (RTVM-006/008), so it
    # runs for real regardless of whether the interactive protocol has
    # automated coverage yet.
    $FirstByteCeilingMs = 16000.0   # RTVM-501's 15s threshold + 1.0s tolerance
    $GapCeilingMs        = 11000.0  # RTVM-502's 10s interval + 1.0s tolerance

    # Part 1 - the four ordinary fixtures. Each is bounded far more tightly
    # by RTVM-500 (10s) than the 16.0s TP-504 asks for; run genuinely
    # timestamped rather than assumed passing.
    foreach ($key in @('easy', 'hard17', 'unsolvable', 'badchar')) {
        $fixturePath = $resolvedFixtures[$key]
        $expectedExit = $fixtureNames[$key].ExpectedExit
        $ts = Invoke-SudokuTimestamped -Exe $Exe -ArgList @($fixturePath) -TimeoutSec 30
        $gaps = Measure-NeverSilent -Events $ts.Events -WindowEndMs $ts.WindowEndMs

        $failReason = Get-FailureReason -Result $ts -Fallback $null
        if (-not $failReason -and $ts.TimedOut) {
            $failReason = "process still running after the 30s per-run ceiling"
        }
        if (-not $failReason -and $ts.ExitCode -ne $expectedExit) {
            $failReason = "exit code $($ts.ExitCode) did not match the expected $expectedExit for this fixture class - a timing figure from a wrong outcome is not evidence about RTVM-504"
        }
        if (-not $failReason -and $null -eq $gaps.FirstByteMs) {
            $failReason = 'process produced zero bytes on either stream'
        }
        if (-not $failReason -and $gaps.FirstByteMs -gt $FirstByteCeilingMs) {
            $failReason = "first byte at $([math]::Round($gaps.FirstByteMs, 1))ms exceeds the ${FirstByteCeilingMs}ms ceiling"
        }
        if (-not $failReason -and $gaps.MaxGapAfterFirstMs -gt $GapCeilingMs) {
            $failReason = "a $([math]::Round($gaps.MaxGapAfterFirstMs, 1))ms gap after the first byte exceeds the ${GapCeilingMs}ms ceiling"
        }

        Add-Check -Checks $Checks -Tp 'TP-504' -Case $key -State $(if ($failReason) { 'FAIL' } else { 'PASS' }) `
            -Expected "first byte <= ${FirstByteCeilingMs}ms, no gap after it > ${GapCeilingMs}ms, exit $expectedExit" `
            -Observed ([ordered]@{
                    firstByteMs = if ($null -ne $gaps.FirstByteMs) { [math]::Round($gaps.FirstByteMs, 1) } else { $null }
                    maxGapAfterFirstMs = if ($null -ne $gaps.MaxGapAfterFirstMs) { [math]::Round($gaps.MaxGapAfterFirstMs, 1) } else { $null }
                    exitCode    = $ts.ExitCode
                    eventCount  = $ts.Events.Count
                } | ConvertTo-Json -Compress) `
            -Reason $failReason
    }

    # Part 2 - the long-solve hook run, to 60s. Needs the hook to be
    # observably active (same probe TP-501..503 use); if it isn't, this is
    # genuinely NOT-RUN rather than a guess.
    if ($probe.Active) {
        $hookMs = 65000
        $ts = Invoke-SudokuTimestamped -Exe $Exe -ArgList @($resolvedFixtures['easy']) `
            -EnvVars @{ SUDOKU_DIAG_MIN_SOLVE_MS = $hookMs } -TimeoutSec 60
        $gaps = Measure-NeverSilent -Events $ts.Events -WindowEndMs $ts.WindowEndMs

        $failReason = Get-FailureReason -Result $ts -Fallback $null
        if (-not $failReason -and $null -eq $gaps.FirstByteMs) {
            $failReason = 'process produced zero bytes on either stream in the 60s window'
        }
        if (-not $failReason -and $gaps.FirstByteMs -gt $FirstByteCeilingMs) {
            $failReason = "first byte at $([math]::Round($gaps.FirstByteMs, 1))ms exceeds the ${FirstByteCeilingMs}ms ceiling"
        }
        if (-not $failReason -and $gaps.MaxGapAfterFirstMs -gt $GapCeilingMs) {
            $failReason = "a $([math]::Round($gaps.MaxGapAfterFirstMs, 1))ms gap after the first byte exceeds the ${GapCeilingMs}ms ceiling"
        }

        Add-Check -Checks $Checks -Tp 'TP-504' -Case 'long-solve-hook' -State $(if ($failReason) { 'FAIL' } else { 'PASS' }) `
            -Expected "first byte <= ${FirstByteCeilingMs}ms, no gap after it > ${GapCeilingMs}ms, observed to 60000ms (SUDOKU_DIAG_MIN_SOLVE_MS=$hookMs)" `
            -Observed ([ordered]@{
                    firstByteMs = if ($null -ne $gaps.FirstByteMs) { [math]::Round($gaps.FirstByteMs, 1) } else { $null }
                    maxGapAfterFirstMs = if ($null -ne $gaps.MaxGapAfterFirstMs) { [math]::Round($gaps.MaxGapAfterFirstMs, 1) } else { $null }
                    windowEndMs = [math]::Round($ts.WindowEndMs, 1)
                    eventCount  = $ts.Events.Count
                    timedOut    = $ts.TimedOut
                } | ConvertTo-Json -Compress) `
            -Reason $failReason
    }
    else {
        Add-Check -Checks $Checks -Tp 'TP-504' -Case 'long-solve-hook' -State 'NOT-RUN' -Reason $probe.Reason
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

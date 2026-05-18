[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputPath,
    [int]$LongSentenceChars = 80,
    [int]$TopRepeatedPhrases = 30,
    [switch]$IncludePromptPack
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$reviewScript = Join-Path $ScriptRoot "Review-CnAcademicText.ps1"
if (-not (Test-Path $reviewScript)) {
    throw "Review-CnAcademicText.ps1 not found beside this compatibility wrapper."
}

$reviewArgs = @{
    InputPath = $InputPath
    LongSentenceChars = $LongSentenceChars
    TopRepeatedPhrases = $TopRepeatedPhrases
}

if (-not $OutputPath) {
    $inputFull = Resolve-Path $InputPath
    $OutputPath = Join-Path (Split-Path $inputFull) "academic_text_review.md"
}

if ($OutputPath) {
    $outputFull = [IO.Path]::GetFullPath($OutputPath)
    $outputDir = Split-Path -Parent $outputFull
    if (-not $outputDir) { $outputDir = (Get-Location).Path }
    $reviewArgs.OutputDir = $outputDir
} else {
    $outputDir = $null
}

if ($IncludePromptPack) {
    $reviewArgs.IncludePromptPack = $true
}

& $reviewScript @reviewArgs

if ($OutputPath) {
    $defaultReport = Join-Path $outputDir "01_originality_report.md"
    if (Test-Path $defaultReport) {
        Copy-Item -Force -Path $defaultReport -Destination $outputFull
        Write-Host "Compatibility report copied to: $outputFull"
    }
}


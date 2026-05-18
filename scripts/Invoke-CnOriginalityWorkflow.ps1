[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputDir,
    [string]$RevisedPath,
    [switch]$CompareWhenRevised
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $OutputDir) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $base = [IO.Path]::GetFileNameWithoutExtension($InputPath)
    $OutputDir = Join-Path (Get-Location) "$base`_cn_originality_$stamp"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

& (Join-Path $ScriptRoot "Review-CnAcademicText.ps1") -InputPath $InputPath -OutputDir $OutputDir -IncludePromptPack

if ($CompareWhenRevised -and $RevisedPath) {
    & (Join-Path $ScriptRoot "Compare-CnDrafts.ps1") -OriginalPath $InputPath -RevisedPath $RevisedPath -OutputPath (Join-Path $OutputDir "07_draft_similarity_report.csv")
}

Write-Host ""
Write-Host "Workflow complete."
Write-Host "Open the report:"
Write-Host "  $(Join-Path $OutputDir '01_originality_report.md')"




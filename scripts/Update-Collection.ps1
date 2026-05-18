[CmdletBinding()]
param(
    [switch]$SeedOnly,
    [int]$MaxPerQuery = 0,
    [switch]$CheckHashes,
    [int]$DownloadTimeoutSec = 60
)

$ErrorActionPreference = "Stop"
$SkillRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

if ($SeedOnly -or $MaxPerQuery -eq 0) {
    & (Join-Path $PSScriptRoot "Collect-GitHubTemplates.ps1") -SeedOnly -DownloadTimeoutSec $DownloadTimeoutSec
}

if ($MaxPerQuery -gt 0) {
    & (Join-Path $PSScriptRoot "Collect-GitHubTemplates.ps1") -MaxPerQuery $MaxPerQuery -DownloadTimeoutSec $DownloadTimeoutSec
}

if ($CheckHashes) {
    & (Join-Path $PSScriptRoot "Validate-Catalog.ps1") -CheckHashes
} else {
    & (Join-Path $PSScriptRoot "Validate-Catalog.ps1")
}

Write-Host ""
Write-Host "Update pass completed in $SkillRoot"
Write-Host "Review changes, then run:"
Write-Host "  git add ."
Write-Host "  git commit -m `"Update thesis template collection`""
Write-Host "  git push"



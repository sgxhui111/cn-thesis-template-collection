[CmdletBinding()]
param(
    [string]$Catalog = "assets/catalog.csv",
    [switch]$CheckHashes
)

$ErrorActionPreference = "Stop"
$SkillRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$CatalogPath = Join-Path $SkillRoot $Catalog

$RequiredFields = @(
    "id", "university", "aliases", "level", "template_type", "format",
    "source_kind", "source_url", "download_url", "local_path", "sha256",
    "license", "last_checked", "status", "notes"
)

$AllowedLevels = @("undergraduate", "graduate", "master", "doctor", "multiple", "unknown")
$AllowedTypes = @("thesis", "dissertation", "proposal", "defense", "format-requirement", "multiple", "unknown")
$AllowedFormats = @("latex", "word", "pdf", "html", "zip", "multiple", "unknown")
$AllowedSources = @("official", "github", "ctan", "overleaf", "other-public")
$AllowedStatuses = @("downloaded", "metadata-only", "failed", "needs-review")

function Add-ErrorMessage([System.Collections.Generic.List[string]]$Errors, [string]$Message) {
    $Errors.Add($Message) | Out-Null
}

function Test-Url([string]$Value) {
    if (-not $Value) { return $false }
    return $Value -match "^https?://"
}

if (-not (Test-Path $CatalogPath)) {
    throw "Catalog not found: $CatalogPath"
}

$errors = [System.Collections.Generic.List[string]]::new()
$headerLine = Get-Content -Path $CatalogPath -Encoding UTF8 -TotalCount 1
$headers = $headerLine -split ","
$headers = @($headers | ForEach-Object { $_.Trim('"') })

foreach ($field in $RequiredFields) {
    if ($headers -notcontains $field) {
        Add-ErrorMessage $errors "Missing catalog column: $field"
    }
}

$rows = @(Import-Csv -Path $CatalogPath -Encoding UTF8)
if ($rows.Count -eq 0) {
    Add-ErrorMessage $errors "Catalog has no rows."
}

$duplicateIds = @($rows | Where-Object { $_.id } | Group-Object id | Where-Object { $_.Count -gt 1 })
foreach ($group in $duplicateIds) {
    Add-ErrorMessage $errors "Duplicate id: $($group.Name)"
}

$duplicateSources = @($rows | Where-Object { $_.source_url } | Group-Object source_url | Where-Object { $_.Count -gt 1 })
foreach ($group in $duplicateSources) {
    Add-ErrorMessage $errors "Duplicate source_url: $($group.Name)"
}

$rowNumber = 1
foreach ($row in $rows) {
    $rowNumber += 1
    $label = "row $rowNumber ($($row.id))"

    if (-not $row.id) { Add-ErrorMessage $errors "${label}: id is required." }
    if (-not $row.university) { Add-ErrorMessage $errors "${label}: university is required." }
    if (-not (Test-Url $row.source_url)) { Add-ErrorMessage $errors "${label}: source_url must start with http:// or https://." }
    if ($row.download_url -and -not (Test-Url $row.download_url)) { Add-ErrorMessage $errors "${label}: download_url must start with http:// or https:// when present." }
    if ($AllowedLevels -notcontains $row.level) { Add-ErrorMessage $errors "${label}: invalid level '$($row.level)'." }
    if ($AllowedTypes -notcontains $row.template_type) { Add-ErrorMessage $errors "${label}: invalid template_type '$($row.template_type)'." }
    if ($AllowedFormats -notcontains $row.format) { Add-ErrorMessage $errors "${label}: invalid format '$($row.format)'." }
    if ($AllowedSources -notcontains $row.source_kind) { Add-ErrorMessage $errors "${label}: invalid source_kind '$($row.source_kind)'." }
    if ($AllowedStatuses -notcontains $row.status) { Add-ErrorMessage $errors "${label}: invalid status '$($row.status)'." }

    if ($row.last_checked -and $row.last_checked -notmatch "^\d{4}-\d{2}-\d{2}$") {
        Add-ErrorMessage $errors "${label}: last_checked must use YYYY-MM-DD."
    }

    if ($row.status -eq "downloaded") {
        if (-not $row.local_path) {
            Add-ErrorMessage $errors "${label}: downloaded row must have local_path."
        } else {
            $filePath = Join-Path $SkillRoot $row.local_path
            if (-not (Test-Path $filePath)) {
                Add-ErrorMessage $errors "${label}: local_path does not exist: $($row.local_path)"
            } elseif ($CheckHashes) {
                if (-not $row.sha256) {
                    Add-ErrorMessage $errors "${label}: downloaded row must have sha256 when -CheckHashes is used."
                } else {
                    $actual = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
                    if ($actual -ne $row.sha256.ToLowerInvariant()) {
                        Add-ErrorMessage $errors "${label}: sha256 mismatch for $($row.local_path)."
                    }
                }
            }
        }
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Error $message -ErrorAction Continue
    }
    Write-Error "Catalog validation failed with $($errors.Count) error(s)."
    exit 1
}

$downloaded = @($rows | Where-Object { $_.status -eq "downloaded" }).Count
$universities = @($rows | Where-Object { $_.university -and $_.university -ne "多校合集" } | Select-Object -ExpandProperty university -Unique).Count

Write-Host "Catalog validation passed."
Write-Host "Rows: $($rows.Count)"
Write-Host "Downloaded rows: $downloaded"
Write-Host "Unique universities: $universities"




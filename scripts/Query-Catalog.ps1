[CmdletBinding()]
param(
    [string]$Level,
    [string]$Format,
    [string]$Status,
    [string]$SourceKind,
    [int]$Limit = 50,
    [string]$Catalog = "assets/catalog.csv",
    [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
    [string[]]$Terms
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SkillRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$CatalogPath = Join-Path $SkillRoot $Catalog

if (-not (Test-Path $CatalogPath)) {
    throw "Catalog not found: $CatalogPath"
}

$rows = @(Get-Content -Path $CatalogPath -Encoding UTF8 | ConvertFrom-Csv)
$termsLower = @($Terms | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })

$matched = @($rows | Where-Object {
    $row = $_
    if ($Level -and $row.level -ne $Level) { return $false }
    if ($Format -and $row.format -ne $Format -and $row.format -ne "multiple") { return $false }
    if ($Status -and $row.status -ne $Status) { return $false }
    if ($SourceKind -and $row.source_kind -ne $SourceKind) { return $false }
    if ($termsLower.Count -eq 0) { return $true }

    $haystack = @(
        $row.id, $row.university, $row.aliases, $row.level, $row.template_type,
        $row.format, $row.source_kind, $row.source_url, $row.local_path,
        $row.license, $row.notes
    ) -join " "
    $haystack = $haystack.ToLowerInvariant()

    foreach ($term in $termsLower) {
        if (-not $haystack.Contains($term)) { return $false }
    }
    return $true
})

if ($matched.Count -eq 0) {
    Write-Host "No catalog rows matched."
    exit 2
}

foreach ($row in ($matched | Select-Object -First $Limit)) {
    Write-Host "$($row.university) | $($row.level) | $($row.format) | $($row.source_kind) | $($row.status)"
    Write-Host "  id: $($row.id)"
    Write-Host "  source: $($row.source_url)"
    if ($row.local_path) { Write-Host "  local: $(Join-Path $SkillRoot $row.local_path)" }
    if ($row.sha256) { Write-Host "  sha256: $($row.sha256)" }
    if ($row.notes) { Write-Host "  notes: $($row.notes)" }
}

if ($matched.Count -gt $Limit) {
    Write-Host "... $($matched.Count - $Limit) more rows"
}



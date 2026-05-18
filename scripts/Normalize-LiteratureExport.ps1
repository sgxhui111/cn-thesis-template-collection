[CmdletBinding()]
param(
    [string]$InputDir = "literature-search/exports",
    [string]$OutputPath,
    [switch]$IncludeRaw
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Normalize-Title([string]$Title) {
    return (($Title -replace "\s+", " " -replace "[\p{P}\p{S}]", "").Trim().ToLowerInvariant())
}

function New-Record([hashtable]$Values) {
    $fields = "source_file", "source_format", "title", "authors", "year", "journal", "doi", "url", "abstract", "keywords", "raw"
    $obj = [ordered]@{}
    foreach ($field in $fields) { $obj[$field] = "" }
    foreach ($key in $Values.Keys) {
        if ($obj.Contains($key)) { $obj[$key] = [string]$Values[$key] }
    }
    return [pscustomobject]$obj
}

function Parse-RisFile([string]$Path) {
    $records = [System.Collections.Generic.List[object]]::new()
    $current = @{}
    $rawLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
        if (-not $line.Trim()) { continue }
        $rawLines.Add($line) | Out-Null
        if ($line -match "^([A-Z0-9]{2})  - (.*)$") {
            $tag = $Matches[1]
            $value = $Matches[2].Trim()
            switch ($tag) {
                "TY" { $current = @{}; $rawLines.Clear(); $rawLines.Add($line) | Out-Null }
                "TI" { $current.title = $value }
                "T1" { if (-not $current.title) { $current.title = $value } }
                "AU" { $current.authors = (($current.authors, $value | Where-Object { $_ }) -join "; ") }
                "PY" { $current.year = $value }
                "Y1" { if (-not $current.year) { $current.year = ($value -split "/")[0] } }
                "JO" { $current.journal = $value }
                "JF" { if (-not $current.journal) { $current.journal = $value } }
                "DO" { $current.doi = $value }
                "UR" { $current.url = $value }
                "AB" { $current.abstract = $value }
                "KW" { $current.keywords = (($current.keywords, $value | Where-Object { $_ }) -join "; ") }
                "ER" {
                    $current.source_file = Split-Path $Path -Leaf
                    $current.source_format = "RIS"
                    if ($IncludeRaw) { $current.raw = ($rawLines -join "\n") }
                    $records.Add((New-Record $current)) | Out-Null
                    $current = @{}
                    $rawLines.Clear()
                }
            }
        }
    }
    return $records
}

function Parse-BibFile([string]$Path) {
    $text = Get-Content -Path $Path -Encoding UTF8 -Raw
    $records = [System.Collections.Generic.List[object]]::new()
    $entries = [regex]::Matches($text, "@\w+\s*\{[^@]+?(?=\r?\n@|\z)", "Singleline")
    foreach ($entry in $entries) {
        $raw = $entry.Value
        $values = @{
            source_file = Split-Path $Path -Leaf
            source_format = "BibTeX"
        }
        foreach ($field in "title", "author", "year", "journal", "doi", "url", "abstract", "keywords") {
            $pattern = "(?im)^\s*$field\s*=\s*[\{\`"](.+?)[\}\`"]\s*,?\s*$"
            $match = [regex]::Match($raw, $pattern)
            if ($match.Success) {
                $value = ($match.Groups[1].Value -replace "\s+", " ").Trim()
                switch ($field) {
                    "author" { $values.authors = ($value -replace "\s+and\s+", "; ") }
                    default { $values[$field] = $value }
                }
            }
        }
        if ($IncludeRaw) { $values.raw = $raw }
        $records.Add((New-Record $values)) | Out-Null
    }
    return $records
}

function Parse-CsvFile([string]$Path) {
    $rows = @(Import-Csv -Path $Path -Encoding UTF8)
    return @($rows | ForEach-Object {
        $row = $_
        $values = @{
            source_file = Split-Path $Path -Leaf
            source_format = "CSV"
            title = ($row.title, $row.Title, $row.'Article Title', $row.'Document Title' | Where-Object { $_ } | Select-Object -First 1)
            authors = ($row.authors, $row.Authors, $row.Author, $row.'Author(s)' | Where-Object { $_ } | Select-Object -First 1)
            year = ($row.year, $row.Year, $row.'Publication Year', $row.PY | Where-Object { $_ } | Select-Object -First 1)
            journal = ($row.journal, $row.Journal, $row.'Source title', $row.Source | Where-Object { $_ } | Select-Object -First 1)
            doi = ($row.doi, $row.DOI | Where-Object { $_ } | Select-Object -First 1)
            url = ($row.url, $row.URL, $row.Link | Where-Object { $_ } | Select-Object -First 1)
            abstract = ($row.abstract, $row.Abstract | Where-Object { $_ } | Select-Object -First 1)
            keywords = ($row.keywords, $row.Keywords | Where-Object { $_ } | Select-Object -First 1)
        }
        if ($IncludeRaw) { $values.raw = ($row | ConvertTo-Json -Compress) }
        New-Record $values
    })
}

if (-not (Test-Path $InputDir)) {
    throw "Input directory not found: $InputDir"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Resolve-Path $InputDir) "literature_catalog.csv"
}

$all = [System.Collections.Generic.List[object]]::new()
$files = Get-ChildItem -Path $InputDir -File -Include *.ris, *.bib, *.csv -Recurse
foreach ($file in $files) {
    if ($file.FullName -eq (Resolve-Path -Path $OutputPath -ErrorAction SilentlyContinue)) { continue }
    switch ($file.Extension.ToLowerInvariant()) {
        ".ris" { foreach ($record in Parse-RisFile $file.FullName) { $all.Add($record) | Out-Null } }
        ".bib" { foreach ($record in Parse-BibFile $file.FullName) { $all.Add($record) | Out-Null } }
        ".csv" { foreach ($record in Parse-CsvFile $file.FullName) { $all.Add($record) | Out-Null } }
    }
}

$seen = @{}
$deduped = [System.Collections.Generic.List[object]]::new()
foreach ($record in $all) {
    $doiKey = $record.doi.Trim().ToLowerInvariant()
    $titleKey = Normalize-Title $record.title
    $key = if ($doiKey) { "doi:$doiKey" } elseif ($titleKey) { "title:$titleKey" } else { "row:$($deduped.Count)" }
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $deduped.Add($record) | Out-Null
}

$deduped | Export-Csv -Path $OutputPath -Encoding UTF8 -NoTypeInformation
Write-Host "Input files: $($files.Count)"
Write-Host "Imported records: $($all.Count)"
Write-Host "Deduplicated records: $($deduped.Count)"
Write-Host "Catalog written to: $OutputPath"



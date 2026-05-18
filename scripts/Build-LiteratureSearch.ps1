[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Query,
    [string]$EnglishQuery,
    [int]$StartYear,
    [int]$EndYear,
    [string]$OutputDir = "literature-search",
    [string]$TopicName = "topic"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Quote-Terms([string]$Text) {
    $terms = @($Text -split "[,，;；\s]+" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
    if ($terms.Count -eq 0) { return '"' + $Text + '"' }
    return (($terms | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join " OR ")
}

function UrlEncode([string]$Text) {
    return [uri]::EscapeDataString($Text)
}

$topicSafe = ($TopicName -replace "[^\w\-\u4e00-\u9fff]+", "_").Trim("_")
if (-not $topicSafe) { $topicSafe = "topic" }
$runDir = Join-Path $OutputDir $topicSafe
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runDir "exports") | Out-Null

$yearText = ""
if ($StartYear -and $EndYear) { $yearText = "$StartYear-$EndYear" }
elseif ($StartYear) { $yearText = "$StartYear-" }
elseif ($EndYear) { $yearText = "-$EndYear" }
else { $yearText = "不限" }

$intl = $EnglishQuery
if (-not $intl) { $intl = $Query }

$cnkiQuery = "主题=($Query)"
$wosQuery = "TS=(" + (Quote-Terms $intl) + ")"
$scopusQuery = "TITLE-ABS-KEY(" + (Quote-Terms $intl) + ")"
$scholarQuery = $intl
$openQuery = $intl
if ($StartYear -and $EndYear) {
    $wosQuery = "$wosQuery AND PY=($StartYear-$EndYear)"
    $scopusQuery = "$scopusQuery AND PUBYEAR > $($StartYear - 1) AND PUBYEAR < $($EndYear + 1)"
    $scholarQuery = "$scholarQuery after:$StartYear before:$EndYear"
}

$rows = @(
    [pscustomobject]@{
        database = "Web of Science"
        query = $wosQuery
        url = "https://www.webofscience.com/wos/woscc/basic-search"
        export_format = "RIS or BibTeX or CSV"
        access_note = "Use institutional access or Clarivate API entitlement. Export metadata only."
    },
    [pscustomobject]@{
        database = "Scopus"
        query = $scopusQuery
        url = "https://www.scopus.com/search/form.uri"
        export_format = "RIS or BibTeX or CSV"
        access_note = "Use institutional access or Elsevier API key where authorized. Export metadata only."
    },
    [pscustomobject]@{
        database = "Google Scholar"
        query = $scholarQuery
        url = "https://scholar.google.com/scholar?q=$(UrlEncode $scholarQuery)"
        export_format = "BibTeX or RefMan from Cite/My Library"
        access_note = "Manual search/export. Do not scrape or attempt bulk automated access."
    },
    [pscustomobject]@{
        database = "CNKI"
        query = $cnkiQuery
        url = "https://www.cnki.net/"
        export_format = "EndNote, RefWorks/RIS-like text, GB/T 7714, or BibTeX when available"
        access_note = "Use authorized CNKI account/session. Export metadata from the official UI."
    },
    [pscustomobject]@{
        database = "OpenAlex/Crossref"
        query = $openQuery
        url = "https://api.openalex.org/works?search=$(UrlEncode $openQuery)"
        export_format = "JSON or CSV"
        access_note = "Open metadata fallback; verify records before citation."
    }
)

$csvPath = Join-Path $runDir "search_queries.csv"
$mdPath = Join-Path $runDir "search_plan.md"
$rows | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation

$md = [System.Collections.Generic.List[string]]::new()
$md.Add("# 多数据库文献检索计划") | Out-Null
$md.Add("") | Out-Null
$md.Add("| 项目 | 内容 |") | Out-Null
$md.Add("| --- | --- |") | Out-Null
$md.Add("| 中文主题 | $Query |") | Out-Null
$md.Add("| 英文主题 | $intl |") | Out-Null
$md.Add("| 年份范围 | $yearText |") | Out-Null
$md.Add('| 导出目录 | `exports/` |') | Out-Null
$md.Add("") | Out-Null
$md.Add("## 检索式") | Out-Null
$md.Add("") | Out-Null
foreach ($row in $rows) {
    $md.Add("### $($row.database)") | Out-Null
    $md.Add("") | Out-Null
    $md.Add('```text') | Out-Null
    $md.Add($row.query) | Out-Null
    $md.Add('```') | Out-Null
    $md.Add("") | Out-Null
    $md.Add("- 入口：$($row.url)") | Out-Null
    $md.Add("- 推荐导出：$($row.export_format)") | Out-Null
    $md.Add("- 合规说明：$($row.access_note)") | Out-Null
    $md.Add("") | Out-Null
}
$md.Add("## 检索记录表") | Out-Null
$md.Add("") | Out-Null
$md.Add("| 数据库 | 检索日期 | 命中数 | 导出文件 | 备注 |") | Out-Null
$md.Add("| --- | --- | ---: | --- | --- |") | Out-Null
foreach ($row in $rows) {
    $md.Add("| $($row.database) |  |  |  |  |") | Out-Null
}
$md.Add("") | Out-Null
$md.Add("## 下一步") | Out-Null
$md.Add("") | Out-Null
$md.Add("1. 在授权数据库中运行上面的检索式。") | Out-Null
$md.Add('2. 将导出的 `.ris`、`.bib`、`.csv` 文件放入 `exports/`。') | Out-Null
$md.Add('3. 运行 `Normalize-LiteratureExport.ps1 -InputDir exports` 合并去重。') | Out-Null

Set-Content -Path $mdPath -Encoding UTF8 -Value ($md -join [Environment]::NewLine)
Write-Host "Search plan written to: $mdPath"
Write-Host "Query table written to: $csvPath"




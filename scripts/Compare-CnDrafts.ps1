[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OriginalPath,
    [Parameter(Mandatory = $true)]
    [string]$RevisedPath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Read-DocxText([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if (-not $entry) {
            $entry = $zip.Entries | Where-Object { ($_.FullName -replace "\\", "/") -eq "word/document.xml" } | Select-Object -First 1
        }
        if (-not $entry) { return "" }
        $stream = $entry.Open()
        try {
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
            $xmlText = $reader.ReadToEnd()
        } finally {
            if ($reader) { $reader.Dispose() }
            $stream.Dispose()
        }
        [xml]$xml = $xmlText
        $ns = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
        $ns.AddNamespace("w", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
        $paragraphs = [System.Collections.Generic.List[string]]::new()
        foreach ($p in $xml.SelectNodes("//w:p", $ns)) {
            $texts = @()
            foreach ($t in $p.SelectNodes(".//w:t", $ns)) { $texts += $t.InnerText }
            $line = ($texts -join "").Trim()
            if ($line) { $paragraphs.Add($line) | Out-Null }
        }
        return ($paragraphs -join "`n`n")
    } finally {
        $zip.Dispose()
    }
}

function Read-Plain([string]$Path) {
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -eq ".docx") { return Read-DocxText $Path }
    return Get-Content -Path $Path -Encoding UTF8 -Raw
}

function Normalize-Cn([string]$Text) {
    return ($Text -replace "\s+", "" -replace "[，。！？；：、（）()\[\]《》〈〉,.!?;:]", "").Trim()
}

function Get-Phrases([string]$Text, [int]$N) {
    $norm = Normalize-Cn $Text
    $set = [System.Collections.Generic.HashSet[string]]::new()
    for ($i = 0; $i -le $norm.Length - $N; $i += 1) {
        $set.Add($norm.Substring($i, $N)) | Out-Null
    }
    return $set
}

function Jaccard($A, $B) {
    if ($A.Count -eq 0 -and $B.Count -eq 0) { return 1.0 }
    $intersection = 0
    foreach ($item in $A) { if ($B.Contains($item)) { $intersection += 1 } }
    $union = $A.Count + $B.Count - $intersection
    if ($union -eq 0) { return 0 }
    return [Math]::Round($intersection / $union, 4)
}

$original = Read-Plain $OriginalPath
$revised = Read-Plain $RevisedPath
$origNorm = Normalize-Cn $original
$revNorm = Normalize-Cn $revised

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($n in 4, 5, 6, 8, 10) {
    $a = Get-Phrases $original $n
    $b = Get-Phrases $revised $n
    $rows.Add([pscustomobject]@{
        ngram = $n
        original_phrases = $a.Count
        revised_phrases = $b.Count
        overlap_ratio = Jaccard $a $b
    }) | Out-Null
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path (Resolve-Path $RevisedPath)) "draft_similarity_report.csv"
}
$rows | Export-Csv -Path $OutputPath -Encoding UTF8 -NoTypeInformation

Write-Host "Original chars: $($origNorm.Length)"
Write-Host "Revised chars: $($revNorm.Length)"
Write-Host "Similarity report: $OutputPath"




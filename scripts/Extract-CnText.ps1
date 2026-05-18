[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Read-DocxText([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $parts = @("word/document.xml", "word/footnotes.xml", "word/endnotes.xml")
        $paragraphs = [System.Collections.Generic.List[string]]::new()
        foreach ($part in $parts) {
            $entry = $zip.GetEntry($part)
            if (-not $entry) {
                $entry = $zip.Entries | Where-Object { ($_.FullName -replace "\\", "/") -eq $part } | Select-Object -First 1
            }
            if (-not $entry) { continue }
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
            foreach ($p in $xml.SelectNodes("//w:p", $ns)) {
                $texts = @()
                foreach ($t in $p.SelectNodes(".//w:t", $ns)) {
                    $texts += $t.InnerText
                }
                $line = ($texts -join "").Trim()
                if ($line) { $paragraphs.Add($line) | Out-Null }
            }
        }
        return ($paragraphs -join [Environment]::NewLine)
    } finally {
        $zip.Dispose()
    }
}

if (-not (Test-Path $InputPath)) {
    throw "Input file not found: $InputPath"
}

$full = Resolve-Path $InputPath
$ext = [IO.Path]::GetExtension($full).ToLowerInvariant()
if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($full, ".txt")
}

switch ($ext) {
    ".docx" { $text = Read-DocxText $full }
    ".txt" { $text = Get-Content -Path $full -Encoding UTF8 -Raw }
    ".md" { $text = Get-Content -Path $full -Encoding UTF8 -Raw }
    default { throw "Unsupported file type: $ext. Supported: .docx, .txt, .md" }
}

Set-Content -Path $OutputPath -Encoding UTF8 -Value $text
Write-Host "Extracted text written to: $OutputPath"




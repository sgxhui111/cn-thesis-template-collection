[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputPath,
    [int]$LongSentenceChars = 80,
    [int]$TopRepeatedPhrases = 20
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Count-Occurrences([string]$Text, [string]$Needle) {
    if (-not $Needle) { return 0 }
    return ([regex]::Matches($Text, [regex]::Escape($Needle))).Count
}

function Get-ChineseChars([string]$Text) {
    $chars = [System.Collections.Generic.List[string]]::new()
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -ge 0x4e00 -and $code -le 0x9fff) {
            $chars.Add([string]$ch) | Out-Null
        }
    }
    return $chars
}

function Normalize-Sentence([string]$Sentence) {
    return ($Sentence -replace "\s+", "" -replace "[，。！？；：、（）()\[\]《》〈〉,.!?;:]", "").Trim()
}

function Has-CitationMarker([string]$Text) {
    return $Text -match "(\[[0-9,\-\s]+\]|（[^）]*(19|20)\d{2}[^）]*）|\([^)]*(19|20)\d{2}[^)]*\)|[A-Za-z\u4e00-\u9fff]+等[，,]?\s*(19|20)\d{2})"
}

if (-not (Test-Path $InputPath)) {
    throw "Input file not found: $InputPath"
}

$inputFullPath = Resolve-Path $InputPath
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path $inputFullPath) "academic_text_review.md"
}

$raw = Get-Content -Path $inputFullPath -Encoding UTF8 -Raw
$text = $raw.Trim()
$paragraphs = @($text -split "(\r?\n){2,}" | Where-Object { $_.Trim() })
$sentences = @($text -split "(?<=[。！？!?；;])" | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$normalizedSentences = @($sentences | ForEach-Object {
    $norm = Normalize-Sentence $_
    if ($norm.Length -ge 12) { [pscustomobject]@{ Text = $_; Normalized = $norm } }
} | Where-Object { $_ })

$duplicateSentences = @($normalizedSentences | Group-Object Normalized | Where-Object { $_.Count -gt 1 } | Sort-Object Count -Descending)
$longSentences = @($sentences | Where-Object { (Normalize-Sentence $_).Length -ge $LongSentenceChars })

$claimMarkers = @("研究表明", "已有研究", "学者认为", "数据显示", "调查显示", "结果表明", "文献指出", "普遍认为", "可以看出", "这说明", "显著影响", "重要作用")
$citationGaps = [System.Collections.Generic.List[object]]::new()
foreach ($sentence in $sentences) {
    foreach ($marker in $claimMarkers) {
        if ($sentence.Contains($marker) -and -not (Has-CitationMarker $sentence)) {
            $citationGaps.Add([pscustomobject]@{ Marker = $marker; Sentence = $sentence }) | Out-Null
            break
        }
    }
}

$fillerPhrases = @("具有重要意义", "不可忽视", "在一定程度上", "随着社会的发展", "综上所述", "由此可见", "众所周知", "值得注意的是", "本文认为", "本文通过")
$fillerHits = @($fillerPhrases | ForEach-Object {
    [pscustomobject]@{ Phrase = $_; Count = Count-Occurrences $text $_ }
} | Where-Object { $_.Count -gt 0 } | Sort-Object Count -Descending)

$chars = Get-ChineseChars $text
$phraseCounts = @{}
foreach ($n in 4, 5, 6) {
    for ($i = 0; $i -le $chars.Count - $n; $i += 1) {
        $slice = for ($j = 0; $j -lt $n; $j += 1) { $chars[$i + $j] }
        $phrase = -join $slice
        if ($phrase -match "^(因此|所以|但是|然而|由于|通过|进行|以及|对于)") { continue }
        if (-not $phraseCounts.ContainsKey($phrase)) { $phraseCounts[$phrase] = 0 }
        $phraseCounts[$phrase] += 1
    }
}
$repeatedPhrases = @($phraseCounts.GetEnumerator() |
    Where-Object { $_.Value -ge 3 } |
    Sort-Object Value -Descending |
    Select-Object -First $TopRepeatedPhrases |
    ForEach-Object { [pscustomobject]@{ Phrase = $_.Key; Count = $_.Value } })

$lineCount = ($text -split "\r?\n").Count
$charCount = (Normalize-Sentence $text).Length

$report = [System.Collections.Generic.List[string]]::new()
$report.Add("# 中文学术文本原创性与重复风险审阅报告") | Out-Null
$report.Add("") | Out-Null
$report.Add("> 本报告用于合规写作改进，不能也不应被用于规避 AI 检测、查重系统或学术诚信审查。") | Out-Null
$report.Add("") | Out-Null
$report.Add("## 概览") | Out-Null
$report.Add("") | Out-Null
$report.Add("| 指标 | 数值 |") | Out-Null
$report.Add("| --- | ---: |") | Out-Null
$report.Add("| 段落数 | $($paragraphs.Count) |") | Out-Null
$report.Add("| 句子数 | $($sentences.Count) |") | Out-Null
$report.Add("| 中文有效字符数 | $charCount |") | Out-Null
$report.Add("| 长句数量 | $($longSentences.Count) |") | Out-Null
$report.Add("| 重复句组数 | $($duplicateSentences.Count) |") | Out-Null
$report.Add("| 疑似缺引用句数 | $($citationGaps.Count) |") | Out-Null
$report.Add("") | Out-Null

$report.Add("## 优先修改建议") | Out-Null
$report.Add("") | Out-Null
$report.Add("1. 先补充缺引用的事实判断和研究结论，避免无来源断言。") | Out-Null
$report.Add("2. 对重复句和高频短语进行合并、删减或改写为自己的分析。") | Out-Null
$report.Add("3. 将长句拆成：研究对象、方法、结果、解释。") | Out-Null
$report.Add("4. 对模板化表达补充具体变量、样本、方法、数据或文献来源。") | Out-Null
$report.Add("") | Out-Null

$report.Add("## 重复句") | Out-Null
$report.Add("") | Out-Null
if ($duplicateSentences.Count -eq 0) {
    $report.Add("未发现完全重复的长句。") | Out-Null
} else {
    foreach ($group in $duplicateSentences) {
        $example = $group.Group[0].Text
        $report.Add("- 出现 $($group.Count) 次：$example") | Out-Null
    }
}
$report.Add("") | Out-Null

$report.Add("## 高频短语") | Out-Null
$report.Add("") | Out-Null
if ($repeatedPhrases.Count -eq 0) {
    $report.Add("未发现明显高频中文短语。") | Out-Null
} else {
    foreach ($item in $repeatedPhrases) {
        $report.Add(('- `{0}`：{1} 次' -f $item.Phrase, $item.Count)) | Out-Null
    }
}
$report.Add("") | Out-Null

$report.Add("## 疑似缺引用句") | Out-Null
$report.Add("") | Out-Null
if ($citationGaps.Count -eq 0) {
    $report.Add("未发现明显的有研究、数据、结果表明但无引用标记的句子。") | Out-Null
} else {
    foreach ($gap in $citationGaps) {
        $report.Add("- [$($gap.Marker)] $($gap.Sentence)") | Out-Null
    }
}
$report.Add("") | Out-Null

$report.Add("## 长句") | Out-Null
$report.Add("") | Out-Null
if ($longSentences.Count -eq 0) {
    $report.Add("未发现超过 $LongSentenceChars 个中文有效字符的长句。") | Out-Null
} else {
    foreach ($sentence in $longSentences | Select-Object -First 30) {
        $report.Add("- $sentence") | Out-Null
    }
}
$report.Add("") | Out-Null

$report.Add("## 模板化表达") | Out-Null
$report.Add("") | Out-Null
if ($fillerHits.Count -eq 0) {
    $report.Add("未发现预设列表中的高频模板化表达。") | Out-Null
} else {
    foreach ($hit in $fillerHits) {
        $report.Add(('- `{0}`：{1} 次。建议补充具体对象、数据或文献依据。' -f $hit.Phrase, $hit.Count)) | Out-Null
    }
}
$report.Add("") | Out-Null

$report.Add("## 合规改写提示词") | Out-Null
$report.Add("") | Out-Null
$report.Add("你可以把需要修改的段落连同参考文献发给写作助手，并要求：") | Out-Null
$report.Add("") | Out-Null
$report.Add('```text') | Out-Null
$report.Add("请在不编造数据和文献的前提下，帮我重组这段中文学术表述：") | Out-Null
$report.Add("1. 保留我的核心观点；") | Out-Null
$report.Add("2. 标出需要补充引用的位置；") | Out-Null
$report.Add("3. 将重复或模板化表达改成更具体的论证；") | Out-Null
$report.Add("4. 输出：问题说明、修改稿、需补充来源。") | Out-Null
$report.Add('```') | Out-Null

Set-Content -Path $OutputPath -Encoding UTF8 -Value ($report -join [Environment]::NewLine)
Write-Host "Review report written to: $OutputPath"






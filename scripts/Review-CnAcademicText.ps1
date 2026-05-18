[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputDir,
    [int]$LongSentenceChars = 80,
    [int]$TopRepeatedPhrases = 30,
    [switch]$IncludePromptPack
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Resolve-Path (Join-Path $ScriptRoot "..")
$LexiconRoot = Join-Path $SkillRoot "assets/lexicons"

function Read-Lexicon([string]$Name, [string[]]$Fallback) {
    $path = Join-Path $LexiconRoot $Name
    if (Test-Path $path) {
        return @(Get-Content -Path $path -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    return $Fallback
}

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

function Read-InputText([string]$Path) {
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        ".docx" { return Read-DocxText $Path }
        ".txt" { return Get-Content -Path $Path -Encoding UTF8 -Raw }
        ".md" { return Get-Content -Path $Path -Encoding UTF8 -Raw }
        default { throw "Unsupported file type: $ext. Supported: .docx, .txt, .md" }
    }
}

function Normalize-Cn([string]$Text) {
    return ($Text -replace "\s+", "" -replace "[，。！？；：、（）()\[\]《》〈〉,.!?;:]", "").Trim()
}

function Split-Sentences([string]$Text) {
    return @($Text -split "(?<=[。！？!?；;])" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-ChineseChars([string]$Text) {
    $chars = [System.Collections.Generic.List[string]]::new()
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -ge 0x4e00 -and $code -le 0x9fff) { $chars.Add([string]$ch) | Out-Null }
    }
    return $chars
}

function Test-CitationMarker([string]$Text) {
    return $Text -match "(\[[0-9,\-\s]+\]|（[^）]*(19|20)\d{2}[^）]*）|\([^)]*(19|20)\d{2}[^)]*\)|等[，,]?\s*(19|20)\d{2})"
}

function Add-Issue($Issues, [int]$Para, [int]$Sentence, [string]$Type, [string]$Severity, [string]$Text, [string]$Suggestion) {
    $Issues.Add([pscustomobject]@{
        paragraph_index = $Para
        sentence_index = $Sentence
        issue_type = $Type
        severity = $Severity
        text = $Text
        suggestion = $Suggestion
    }) | Out-Null
}

if (-not (Test-Path $InputPath)) { throw "Input file not found: $InputPath" }
$inputFull = Resolve-Path $InputPath
if (-not $OutputDir) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $base = [IO.Path]::GetFileNameWithoutExtension($inputFull)
    $OutputDir = Join-Path (Split-Path $inputFull) "$base`_originality_review_$stamp"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$claimMarkers = Read-Lexicon "claim_markers.txt" @("研究表明", "数据显示", "已有研究", "结果表明")
$fillerPhrases = Read-Lexicon "filler_phrases.txt" @("具有重要意义", "综上所述")
$stopPhrases = Read-Lexicon "stop_phrases.txt" @("通过", "进行", "以及")
$weakLogicPhrases = Read-Lexicon "weak_logic_phrases.txt" @("在一定程度上", "可能会", "比较重要")

$text = (Read-InputText $inputFull).Trim()
$paragraphs = @($text -split "(\r?\n){2,}" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$sentences = Split-Sentences $text
$issues = [System.Collections.Generic.List[object]]::new()

$paraIndex = 0
$paragraphActions = [System.Collections.Generic.List[object]]::new()
foreach ($paragraph in $paragraphs) {
    $paraIndex += 1
    $paraSentences = Split-Sentences $paragraph
    $risk = 0
    $types = [System.Collections.Generic.List[string]]::new()
    $sentenceIndex = 0
    foreach ($sentence in $paraSentences) {
        $sentenceIndex += 1
        $norm = Normalize-Cn $sentence
        if ($norm.Length -ge $LongSentenceChars) {
            Add-Issue $issues $paraIndex $sentenceIndex "long_sentence" "medium" $sentence "拆成对象、方法、结果、解释几个短句。"
            $risk += 2
            if ($types -notcontains "long_sentence") { $types.Add("long_sentence") | Out-Null }
        }
        foreach ($marker in $claimMarkers) {
            if ($sentence.Contains($marker) -and -not (Test-CitationMarker $sentence)) {
                Add-Issue $issues $paraIndex $sentenceIndex "citation_gap" "high" $sentence "补充来源，或改成自己的限定性分析。"
                $risk += 3
                if ($types -notcontains "citation_gap") { $types.Add("citation_gap") | Out-Null }
                break
            }
        }
        foreach ($phrase in $fillerPhrases) {
            if ($sentence.Contains($phrase)) {
                Add-Issue $issues $paraIndex $sentenceIndex "template_phrase" "medium" $sentence "把空泛评价替换为具体对象、数据、机制或文献依据。"
                $risk += 1
                if ($types -notcontains "template_phrase") { $types.Add("template_phrase") | Out-Null }
                break
            }
        }
        foreach ($phrase in $weakLogicPhrases) {
            if ($sentence.Contains($phrase)) {
                Add-Issue $issues $paraIndex $sentenceIndex "weak_logic_phrase" "medium" $sentence "收窄主张，说明作用对象、条件、机制或证据来源。"
                $risk += 1
                if ($types -notcontains "weak_logic_phrase") { $types.Add("weak_logic_phrase") | Out-Null }
                break
            }
        }
    }
    $hasCitation = Test-CitationMarker $paragraph
    if ($paraSentences.Count -ge 4 -and -not $hasCitation) {
        $risk += 2
        if ($types -notcontains "paragraph_citation_gap") { $types.Add("paragraph_citation_gap") | Out-Null }
    }
    $action = if ($risk -ge 6) { "高优先级：先补来源和证据，再重组段落。" } elseif ($risk -ge 3) { "中优先级：拆句、补引用、减少模板化表达。" } else { "低优先级：局部润色即可。" }
    $paragraphActions.Add([pscustomobject]@{
        paragraph_index = $paraIndex
        risk_score = $risk
        issue_types = ($types -join ";")
        action = $action
        preview = $paragraph.Substring(0, [Math]::Min(80, $paragraph.Length))
    }) | Out-Null
}

$normSentenceRecords = @($sentences | ForEach-Object {
    $norm = Normalize-Cn $_
    if ($norm.Length -ge 12) { [pscustomobject]@{ text = $_; normalized = $norm } }
} | Where-Object { $_ })

$duplicateGroups = @($normSentenceRecords | Group-Object normalized | Where-Object { $_.Count -gt 1 } | Sort-Object Count -Descending)
foreach ($group in $duplicateGroups) {
    Add-Issue $issues 0 0 "duplicate_sentence" "high" $group.Group[0].text "相同句子出现 $($group.Count) 次，建议删除、合并或改成不同论证功能。"
}

$chars = Get-ChineseChars $text
$phraseCounts = @{}
foreach ($n in 4, 5, 6) {
    for ($i = 0; $i -le $chars.Count - $n; $i += 1) {
        $slice = for ($j = 0; $j -lt $n; $j += 1) { $chars[$i + $j] }
        $phrase = -join $slice
        if ($stopPhrases | Where-Object { $phrase.StartsWith($_) }) { continue }
        if (-not $phraseCounts.ContainsKey($phrase)) { $phraseCounts[$phrase] = 0 }
        $phraseCounts[$phrase] += 1
    }
}

$repeatedPhrases = @($phraseCounts.GetEnumerator() |
    Where-Object { $_.Value -ge 3 } |
    Sort-Object Value -Descending |
    Select-Object -First $TopRepeatedPhrases |
    ForEach-Object {
        [pscustomobject]@{ phrase = $_.Key; count = $_.Value; suggestion = "检查是否为术语必要重复；非术语建议替换为具体变量或删减。" }
    })

$sentenceCsv = Join-Path $OutputDir "02_sentence_issues.csv"
$phraseCsv = Join-Path $OutputDir "03_repeated_phrases.csv"
$paragraphCsv = Join-Path $OutputDir "04_paragraph_actions.csv"
$issues | Export-Csv -Path $sentenceCsv -Encoding UTF8 -NoTypeInformation
$repeatedPhrases | Export-Csv -Path $phraseCsv -Encoding UTF8 -NoTypeInformation
$paragraphActions | Export-Csv -Path $paragraphCsv -Encoding UTF8 -NoTypeInformation

$reportPath = Join-Path $OutputDir "01_originality_report.md"
$promptPath = Join-Path $OutputDir "05_prompt_pack.md"
$logPath = Join-Path $OutputDir "06_revision_log_template.md"

$highIssues = @($issues | Where-Object { $_.severity -eq "high" })
$mediumIssues = @($issues | Where-Object { $_.severity -eq "medium" })
$charCount = (Normalize-Cn $text).Length

$report = [System.Collections.Generic.List[string]]::new()
$report.Add("# 中文学术原创性与重复风险报告") | Out-Null
$report.Add("") | Out-Null
$report.Add("> 用途：合规原创性提升、引用补全、结构改进。不能用于规避 AI 检测或查重。") | Out-Null
$report.Add("") | Out-Null
$report.Add("## 概览") | Out-Null
$report.Add("") | Out-Null
$report.Add("| 指标 | 数值 |") | Out-Null
$report.Add("| --- | ---: |") | Out-Null
$report.Add("| 段落数 | $($paragraphs.Count) |") | Out-Null
$report.Add("| 句子数 | $($sentences.Count) |") | Out-Null
$report.Add("| 中文有效字符数 | $charCount |") | Out-Null
$report.Add("| 高风险问题 | $($highIssues.Count) |") | Out-Null
$report.Add("| 中风险问题 | $($mediumIssues.Count) |") | Out-Null
$report.Add("| 重复短语 | $($repeatedPhrases.Count) |") | Out-Null
$report.Add("") | Out-Null
$report.Add("## 最需要先处理的段落") | Out-Null
$report.Add("") | Out-Null
foreach ($p in ($paragraphActions | Sort-Object risk_score -Descending | Select-Object -First 8)) {
    $report.Add("- 段落 $($p.paragraph_index)，风险 $($p.risk_score)：$($p.action)") | Out-Null
}
$report.Add("") | Out-Null
$report.Add("## 高风险问题示例") | Out-Null
$report.Add("") | Out-Null
if ($highIssues.Count -eq 0) {
    $report.Add("未发现高风险问题。") | Out-Null
} else {
    foreach ($issue in ($highIssues | Select-Object -First 20)) {
        $report.Add("- [$($issue.issue_type)] $($issue.text)") | Out-Null
        $report.Add("  - 建议：$($issue.suggestion)") | Out-Null
    }
}
$report.Add("") | Out-Null
$report.Add("## 高频重复短语") | Out-Null
$report.Add("") | Out-Null
if ($repeatedPhrases.Count -eq 0) {
    $report.Add("未发现明显高频短语。") | Out-Null
} else {
    foreach ($item in ($repeatedPhrases | Select-Object -First 20)) {
        $report.Add(("- `{0}`：{1} 次" -f $item.phrase, $item.count)) | Out-Null
    }
}
$report.Add("") | Out-Null
$report.Add("## 输出文件") | Out-Null
$report.Add("") | Out-Null
$report.Add('- `02_sentence_issues.csv`：句子级问题') | Out-Null
$report.Add('- `03_repeated_phrases.csv`：高频短语') | Out-Null
$report.Add('- `04_paragraph_actions.csv`：段落修改优先级') | Out-Null
$report.Add('- `05_prompt_pack.md`：可复制给写作助手的合规提示词') | Out-Null
$report.Add('- `06_revision_log_template.md`：修改记录模板') | Out-Null
Set-Content -Path $reportPath -Encoding UTF8 -Value ($report -join [Environment]::NewLine)

$prompt = @'
# 合规改写提示词包

## 单段改写

请对下面中文学术段落做合规原创性提升：
1. 不编造数据、文献、实验或结论；
2. 保留我的核心观点；
3. 标出需要补充引用的位置；
4. 减少重复句、模板化表达和空泛判断；
5. 输出：问题、修改稿、需补充来源、修改说明。

段落：
【粘贴段落】

## 多文献综合

请基于我提供的文献摘要/笔记，将下面段落从单篇复述改成多文献综合：
1. 写出共识、差异和不足；
2. 每个来源性观点都保留引用；
3. 不添加来源中没有的信息；
4. 最后补一句与我的研究问题的关系。

## 修改记录

请为修改稿生成修改记录：
- 原问题：
- 修改方式：
- 新增/保留引用：
- 是否改变原意：
- 仍需人工核验：
'@
Set-Content -Path $promptPath -Encoding UTF8 -Value $prompt

$log = @'
# 修改记录模板

| 段落 | 原问题 | 修改方式 | 新增/保留引用 | 是否改变原意 | 仍需核验 |
| --- | --- | --- | --- | --- | --- |
| 1 |  |  |  | 否 |  |

'@
Set-Content -Path $logPath -Encoding UTF8 -Value $log

Write-Host "Review completed: $OutputDir"
Write-Host "Report: $reportPath"




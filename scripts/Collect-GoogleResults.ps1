[CmdletBinding()]
param(
    [string]$ApiKey = $env:GOOGLE_API_KEY,
    [string]$Cx = $env:GOOGLE_CSE_ID,
    [int]$MaxPerQuery = 10,
    [switch]$MetadataOnly,
    [string]$Catalog = "assets/catalog.csv",
    [string]$Queries = "assets/sources/google_queries.txt",
    [string]$OutDir = "assets/formats/web",
    [int]$DownloadTimeoutSec = 60
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $ApiKey -or -not $Cx) {
    throw "Set GOOGLE_API_KEY and GOOGLE_CSE_ID, or pass -ApiKey and -Cx. Use Google's official Programmable Search JSON API; do not scrape result pages."
}

$SkillRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$CatalogPath = Join-Path $SkillRoot $Catalog
$QueriesPath = Join-Path $SkillRoot $Queries
$FormatsDir = Join-Path $SkillRoot $OutDir
$Today = (Get-Date).ToString("yyyy-MM-dd")
$Fields = @(
    "id", "university", "aliases", "level", "template_type", "format",
    "source_kind", "source_url", "download_url", "local_path", "sha256",
    "license", "last_checked", "status", "notes"
)

New-Item -ItemType Directory -Force -Path $FormatsDir | Out-Null

function Clean-Text([string]$Text) {
    return (($Text -replace "\s+", " ").Trim())
}

function Get-StableId([string]$Value) {
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hash = $sha1.ComputeHash($bytes)
    return (($hash | ForEach-Object { $_.ToString("x2") }) -join "").Substring(0, 16)
}

function Safe-Segment([string]$Value) {
    $safe = $Value -replace "[^\w\.-]+", "_"
    $safe = $safe.Trim("_")
    if ($safe) { return $safe }
    return "unknown"
}

function Infer-Level([string]$Text) {
    $undergrad = $Text -match "本科|学士|bachelor|undergraduate|毕业设计"
    $grad = $Text -match "研究生|硕士|博士|master|doctor|graduate|dissertation|学位论文"
    if ($undergrad -and $grad) { return "multiple" }
    if ($undergrad) { return "undergraduate" }
    if ($grad) { return "graduate" }
    return "unknown"
}

function Infer-TemplateType([string]$Text) {
    if ($Text -match "开题|proposal") { return "proposal" }
    if ($Text -match "答辩|defense") { return "defense" }
    if ($Text -match "格式|规范|要求|撰写") { return "format-requirement" }
    if ($Text -match "学位论文|硕士|博士|dissertation") { return "dissertation" }
    if ($Text -match "毕业论文|毕业设计|thesis") { return "thesis" }
    return "unknown"
}

function Infer-Format([string]$Text) {
    if ($Text -match "\.docx?($|[?#])|word") { return "word" }
    if ($Text -match "\.pdf($|[?#])|pdf") { return "pdf" }
    if ($Text -match "\.tex($|[?#])|latex|ctex") { return "latex" }
    if ($Text -match "\.zip($|[?#])|\.rar($|[?#])") { return "zip" }
    return "unknown"
}

function Infer-University([string]$Text) {
    $rules = @(
        @{ Pattern = "西安交通大学|xjtu|xi'?an jiaotong"; University = "西安交通大学"; Aliases = "XJTU|Xi'an Jiaotong University" },
        @{ Pattern = "上海交通大学|sjtu|shanghai jiao tong"; University = "上海交通大学"; Aliases = "SJTU|Shanghai Jiao Tong University" },
        @{ Pattern = "清华大学|tsinghua"; University = "清华大学"; Aliases = "THU|Tsinghua University" },
        @{ Pattern = "北京大学|pku|peking university"; University = "北京大学"; Aliases = "PKU|Peking University" },
        @{ Pattern = "中国科学技术大学|ustc"; University = "中国科学技术大学"; Aliases = "USTC|University of Science and Technology of China" },
        @{ Pattern = "中国科学院大学|ucas|university of chinese academy"; University = "中国科学院大学"; Aliases = "UCAS|University of Chinese Academy of Sciences" },
        @{ Pattern = "浙江大学|zju|zhejiang university"; University = "浙江大学"; Aliases = "ZJU|Zhejiang University" },
        @{ Pattern = "南京大学|nju|nanjing university"; University = "南京大学"; Aliases = "NJU|Nanjing University" },
        @{ Pattern = "复旦大学|fudan"; University = "复旦大学"; Aliases = "FDU|Fudan University" },
        @{ Pattern = "北京航空航天大学|北航|buaa|beihang"; University = "北京航空航天大学"; Aliases = "BUAA|Beihang University" },
        @{ Pattern = "华中科技大学|hust"; University = "华中科技大学"; Aliases = "HUST|Huazhong University of Science and Technology" },
        @{ Pattern = "电子科技大学|uestc"; University = "电子科技大学"; Aliases = "UESTC|University of Electronic Science and Technology of China" },
        @{ Pattern = "华南理工大学|scut"; University = "华南理工大学"; Aliases = "SCUT|South China University of Technology" },
        @{ Pattern = "哈尔滨工业大学|哈工大|hit"; University = "哈尔滨工业大学"; Aliases = "HIT|Harbin Institute of Technology" },
        @{ Pattern = "同济大学|tongji"; University = "同济大学"; Aliases = "Tongji University" },
        @{ Pattern = "四川大学|scu|sichuan university"; University = "四川大学"; Aliases = "SCU|Sichuan University" },
        @{ Pattern = "中山大学|sysu|sun yat-sen"; University = "中山大学"; Aliases = "SYSU|Sun Yat-sen University" },
        @{ Pattern = "天津大学|tju|tianjin university"; University = "天津大学"; Aliases = "TJU|Tianjin University" },
        @{ Pattern = "重庆大学|cqu|chongqing university"; University = "重庆大学"; Aliases = "CQU|Chongqing University" },
        @{ Pattern = "南京航空航天大学|南航|nuaa"; University = "南京航空航天大学"; Aliases = "NUAA|Nanjing University of Aeronautics and Astronautics" },
        @{ Pattern = "南方科技大学|sustech"; University = "南方科技大学"; Aliases = "SUSTech|Southern University of Science and Technology" },
        @{ Pattern = "云南大学|ynu|yunnan university"; University = "云南大学"; Aliases = "YNU|Yunnan University" }
    )
    foreach ($rule in $rules) {
        if ($Text -match $rule.Pattern) { return $rule }
    }
    return @{ University = ""; Aliases = "" }
}

function New-CatalogRow([hashtable]$Values) {
    $ordered = [ordered]@{}
    foreach ($field in $Fields) { $ordered[$field] = "" }
    foreach ($key in $Values.Keys) {
        if ($ordered.Contains($key)) { $ordered[$key] = [string]$Values[$key] }
    }
    return [pscustomobject]$ordered
}

function Merge-Rows($Old, $New) {
    $values = @{}
    foreach ($field in $Fields) {
        $newValue = ""
        $oldValue = ""
        if ($New -and $New.PSObject.Properties[$field]) { $newValue = $New.$field }
        if ($Old -and $Old.PSObject.Properties[$field]) { $oldValue = $Old.$field }
        if ($field -eq "status" -and $oldValue -eq "downloaded" -and $newValue -eq "metadata-only") {
            $values[$field] = $oldValue
        } elseif ($newValue) {
            $values[$field] = $newValue
        } else {
            $values[$field] = $oldValue
        }
    }
    if (-not $values["status"]) { $values["status"] = "metadata-only" }
    if (-not $values["last_checked"]) { $values["last_checked"] = $Today }
    return New-CatalogRow $values
}

function Read-CatalogRows([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    return @(Get-Content -Path $Path -Encoding UTF8 | ConvertFrom-Csv)
}

function Read-Queries([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    return @(Get-Content -Path $Path -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") })
}

function Get-DirectExtension([string]$Url) {
    $clean = ($Url -split "[?#]")[0]
    if ($clean -match "\.(pdf|doc|docx|zip|rar|tex)$") { return $Matches[1].ToLowerInvariant() }
    return ""
}

function Download-Row($Row) {
    if (-not $Row.download_url) { throw "missing download_url" }
    $uri = [uri]$Row.download_url
    $domain = Safe-Segment $uri.Host
    $fileName = [IO.Path]::GetFileName(($uri.AbsolutePath -split "[?#]")[0])
    if (-not $fileName) { $fileName = "$($Row.id).bin" }
    $targetDir = Join-Path $FormatsDir $domain
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    $targetPath = Join-Path $targetDir (Safe-Segment $fileName)
    if (Test-Path $targetPath) {
        $existing = Get-Item $targetPath
        if ($existing.Length -gt 0) {
            $hash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
            return @{ local_path = (($targetPath.Substring($SkillRoot.Path.Length + 1)) -replace "\\", "/"); sha256 = $hash }
        }
    }
    $tmpPath = "$targetPath.download"
    if (Test-Path $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force }
    Invoke-WebRequest -Uri $Row.download_url -OutFile $tmpPath -TimeoutSec $DownloadTimeoutSec
    Move-Item -LiteralPath $tmpPath -Destination $targetPath -Force
    $hash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    return @{ local_path = (($targetPath.Substring($SkillRoot.Path.Length + 1)) -replace "\\", "/"); sha256 = $hash }
}

function Write-CatalogRows($Map) {
    $rows = @($Map.Values | Sort-Object id)
    $rows | Select-Object $Fields | Export-Csv -Path $CatalogPath -NoTypeInformation -Encoding UTF8
    return $rows
}

function Search-Google([string]$Query, [int]$Start, [int]$Num) {
    $url = "https://www.googleapis.com/customsearch/v1?key=$([uri]::EscapeDataString($ApiKey))&cx=$([uri]::EscapeDataString($Cx))&q=$([uri]::EscapeDataString($Query))&num=$Num&start=$Start"
    Invoke-RestMethod -Uri $url
}

$existing = Read-CatalogRows $CatalogPath
$byId = @{}
$bySource = @{}
foreach ($row in $existing) {
    if ($row.id) { $byId[$row.id] = $row }
    if ($row.source_url) { $bySource[$row.source_url.TrimEnd("/")] = $row }
}

$checked = 0
$downloaded = 0
$metadata = 0
$failed = 0

foreach ($query in (Read-Queries $QueriesPath)) {
    for ($start = 1; $start -le $MaxPerQuery; $start += 10) {
        $num = [Math]::Min(10, $MaxPerQuery - $start + 1)
        if ($num -le 0) { break }
        $result = Search-Google $query $start $num
        foreach ($item in @($result.items)) {
            $sourceUrl = [string]$item.link
            if (-not $sourceUrl) { continue }
            $text = Clean-Text "$($item.title) $($item.snippet) $sourceUrl"
            $school = Infer-University $text
            $ext = Get-DirectExtension $sourceUrl
            $downloadUrl = ""
            if ($ext) { $downloadUrl = $sourceUrl }
            $row = New-CatalogRow @{
                id = "google_$(Get-StableId $sourceUrl)"
                university = $school.University
                aliases = $school.Aliases
                level = Infer-Level $text
                template_type = Infer-TemplateType $text
                format = Infer-Format $text
                source_kind = $(if ($sourceUrl -match "\.edu\.cn") { "official" } else { "other-public" })
                source_url = $sourceUrl
                download_url = $downloadUrl
                license = "unknown"
                last_checked = $Today
                status = "metadata-only"
                notes = "Google query: $query; $text"
            }
            $old = $null
            if ($byId.ContainsKey($row.id)) { $old = $byId[$row.id] }
            elseif ($bySource.ContainsKey($sourceUrl.TrimEnd("/"))) { $old = $bySource[$sourceUrl.TrimEnd("/")] }
            $merged = Merge-Rows $old $row
            if ($MetadataOnly -or -not $downloadUrl) {
                if ($merged.status -ne "downloaded") { $merged.status = "metadata-only" }
                $metadata += 1
            } else {
                try {
                    $dl = Download-Row $merged
                    $merged.local_path = $dl.local_path
                    $merged.sha256 = $dl.sha256
                    $merged.status = "downloaded"
                    $downloaded += 1
                } catch {
                    $merged.status = "failed"
                    $merged.notes = "$($merged.notes) | download failed: $($_.Exception.Message)"
                    $failed += 1
                }
            }
            $merged.last_checked = $Today
            $byId[$merged.id] = $merged
            if ($merged.source_url) { $bySource[$merged.source_url.TrimEnd("/")] = $merged }
            Write-CatalogRows $byId | Out-Null
            $checked += 1
        }
    }
}

$rows = Write-CatalogRows $byId
Write-Host "catalog: $CatalogPath"
Write-Host "rows: $($rows.Count)"
Write-Host "google results checked: $checked"
Write-Host "downloaded: $downloaded"
Write-Host "metadata-only: $metadata"
Write-Host "failed: $failed"



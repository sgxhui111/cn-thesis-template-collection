[CmdletBinding()]
param(
    [int]$MaxPerQuery = 5,
    [switch]$SeedOnly,
    [switch]$SearchOnly,
    [switch]$MetadataOnly,
    [string]$Catalog = "assets/catalog.csv",
    [string]$Seeds = "assets/sources/seed_sources.csv",
    [string]$Queries = "assets/sources/github_queries.txt",
    [string]$OutDir = "assets/formats/github",
    [int]$DownloadTimeoutSec = 90
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$SkillRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$CatalogPath = Join-Path $SkillRoot $Catalog
$SeedPath = Join-Path $SkillRoot $Seeds
$QueriesPath = Join-Path $SkillRoot $Queries
$FormatsDir = Join-Path $SkillRoot $OutDir
$Today = (Get-Date).ToString("yyyy-MM-dd")
$Fields = @(
    "id", "university", "aliases", "level", "template_type", "format",
    "source_kind", "source_url", "download_url", "local_path", "sha256",
    "license", "last_checked", "status", "notes"
)

New-Item -ItemType Directory -Force -Path $FormatsDir | Out-Null

function Get-GitHubHeaders {
    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "cn-thesis-template-collection"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    }
    return $headers
}

function Invoke-GitHubJson([string]$Url) {
    Invoke-RestMethod -Uri $Url -Headers (Get-GitHubHeaders)
}

function Parse-GitHubSlug([string]$Url) {
    if ($Url -match "github\.com[/:]([^/\s]+)/([^/\s?#.]+)(?:\.git)?") {
        return "$($Matches[1])/$($Matches[2] -replace '\.git$', '')"
    }
    return ""
}

function Clean-Text([string]$Text) {
    return (($Text -replace "\s+", " ").Trim())
}

function Append-Note([string]$Left, [string]$Right) {
    $parts = @()
    foreach ($value in @($Left, $Right)) {
        foreach ($segment in ($value -split "\s+\|\s+")) {
            $text = Clean-Text $segment
            if ($text -and ($parts -notcontains $text)) { $parts += $text }
        }
    }
    return ($parts -join " | ")
}

function Infer-University($Repo) {
    $topics = ""
    if ($Repo.topics) { $topics = ($Repo.topics -join " ") }
    $text = "$($Repo.full_name) $($Repo.name) $($Repo.description) $topics"
    $rules = @(
        @{ Pattern = "xjtu|西安交通大学|xi'?an jiaotong"; University = "西安交通大学"; Aliases = "XJTU|Xi'an Jiaotong University" },
        @{ Pattern = "sjtu|上海交通大学|shanghai jiao tong"; University = "上海交通大学"; Aliases = "SJTU|Shanghai Jiao Tong University" },
        @{ Pattern = "tsinghua|清华|thu[-_]?thesis"; University = "清华大学"; Aliases = "THU|Tsinghua University" },
        @{ Pattern = "pku|北京大学|peking university"; University = "北京大学"; Aliases = "PKU|Peking University" },
        @{ Pattern = "ustc|中国科学技术大学"; University = "中国科学技术大学"; Aliases = "USTC|University of Science and Technology of China" },
        @{ Pattern = "zju|浙江大学|zhejiang university"; University = "浙江大学"; Aliases = "ZJU|Zhejiang University" },
        @{ Pattern = "nju|南京大学|nanjing university"; University = "南京大学"; Aliases = "NJU|Nanjing University" },
        @{ Pattern = "fudan|复旦"; University = "复旦大学"; Aliases = "FDU|Fudan University" },
        @{ Pattern = "buaa|北航|北京航空航天"; University = "北京航空航天大学"; Aliases = "BUAA|Beihang University" },
        @{ Pattern = "bit|北京理工"; University = "北京理工大学"; Aliases = "BIT|Beijing Institute of Technology" },
        @{ Pattern = "hust|华中科技"; University = "华中科技大学"; Aliases = "HUST|Huazhong University of Science and Technology" },
        @{ Pattern = "xdu|西安电子科技"; University = "西安电子科技大学"; Aliases = "XDU|Xidian University" },
        @{ Pattern = "uestc|电子科技大学"; University = "电子科技大学"; Aliases = "UESTC|University of Electronic Science and Technology of China" },
        @{ Pattern = "ncepu|华北电力"; University = "华北电力大学"; Aliases = "NCEPU|North China Electric Power University" },
        @{ Pattern = "tju|天津大学|tianjin university"; University = "天津大学"; Aliases = "TJU|Tianjin University" },
        @{ Pattern = "hit|哈工大|哈尔滨工业大学|hithesis"; University = "哈尔滨工业大学"; Aliases = "HIT|Harbin Institute of Technology" },
        @{ Pattern = "scut|华南理工"; University = "华南理工大学"; Aliases = "SCUT|South China University of Technology" },
        @{ Pattern = "ucas|中国科学院大学|university of chinese academy"; University = "中国科学院大学"; Aliases = "UCAS|University of Chinese Academy of Sciences" },
        @{ Pattern = "cqu|重庆大学|chongqing university"; University = "重庆大学"; Aliases = "CQU|Chongqing University" },
        @{ Pattern = "scu[-_]?thesis|四川大学|sichuan university"; University = "四川大学"; Aliases = "SCU|Sichuan University" },
        @{ Pattern = "sysu|中山大学|sun yat-sen"; University = "中山大学"; Aliases = "SYSU|Sun Yat-sen University" },
        @{ Pattern = "tongji|同济大学"; University = "同济大学"; Aliases = "Tongji University" },
        @{ Pattern = "ynu|云南大学|yunnan university"; University = "云南大学"; Aliases = "YNU|Yunnan University" }
    )
    foreach ($rule in $rules) {
        if ($text -match $rule.Pattern) { return $rule }
    }
    return @{ University = ""; Aliases = "" }
}

function Infer-Level([string]$Text) {
    $undergrad = $Text -match "本科|学士|bachelor|undergraduate"
    $grad = $Text -match "研究生|硕士|博士|master|doctor|graduate|dissertation"
    if ($undergrad -and $grad) { return "multiple" }
    if ($undergrad) { return "undergraduate" }
    if ($grad) { return "graduate" }
    return "unknown"
}

function Infer-TemplateType([string]$Text) {
    if ($Text -match "proposal|开题") { return "proposal" }
    if ($Text -match "defense|答辩|beamer") { return "defense" }
    if ($Text -match "format|规范|要求") { return "format-requirement" }
    if ($Text -match "dissertation|学位论文|博士|硕士") { return "dissertation" }
    if ($Text -match "thesis|毕业论文|毕业设计") { return "thesis" }
    return "unknown"
}

function Infer-Format([string]$Text) {
    $formats = @()
    if ($Text -match "latex|tex|ctex|cls|bibtex") { $formats += "latex" }
    if ($Text -match "word|docx|office") { $formats += "word" }
    if ($Text -match "pdf") { $formats += "pdf" }
    if ($formats.Count -gt 1) { return "multiple" }
    if ($formats.Count -eq 1) { return $formats[0] }
    return "unknown"
}

function Infer-SourceKind([string]$SourceUrl) {
    if ($SourceUrl -match "github\.com") { return "github" }
    if ($SourceUrl -match "ctan\.org|mirrors\..*ctan") { return "ctan" }
    if ($SourceUrl -match "overleaf\.com") { return "overleaf" }
    if ($SourceUrl -match "\.edu\.cn") { return "official" }
    return "other-public"
}

function Safe-Segment([string]$Value) {
    $safe = $Value -replace "[^\w\.-]+", "_"
    $safe = $safe.Trim("_")
    if ($safe) { return $safe }
    return "unknown"
}

function New-CatalogRow([hashtable]$Values) {
    $ordered = [ordered]@{}
    foreach ($field in $Fields) { $ordered[$field] = "" }
    foreach ($key in $Values.Keys) {
        if ($ordered.Contains($key)) { $ordered[$key] = [string]$Values[$key] }
    }
    return [pscustomobject]$ordered
}

function New-RowFromRepo($Repo, $Seed) {
    $slug = $Repo.full_name
    if (-not $slug -and $Seed.source_url) { $slug = Parse-GitHubSlug $Seed.source_url }
    $inferred = Infer-University $Repo
    $description = Clean-Text $Repo.description
    $topics = ""
    if ($Repo.topics) { $topics = ($Repo.topics -join "|") }
    $license = "unknown"
    if ($Seed.license) { $license = $Seed.license }
    elseif ($Repo.license -and $Repo.license.spdx_id) { $license = $Repo.license.spdx_id }
    elseif ($Repo.license -and $Repo.license.name) { $license = $Repo.license.name }
    $defaultBranch = $Repo.default_branch
    if (-not $defaultBranch) { $defaultBranch = "main" }

    return New-CatalogRow @{
        id = If-Value $Seed.id "github_$($slug -replace '/', '_')"
        university = If-Value $Seed.university $inferred.University
        aliases = If-Value $Seed.aliases $inferred.Aliases
        level = If-Value $Seed.level (Infer-Level "$($Repo.name) $description $topics")
        template_type = If-Value $Seed.template_type (Infer-TemplateType "$($Repo.name) $description")
        format = If-Value $Seed.format (Infer-Format "$($Repo.language) $($Repo.name) $description $topics")
        source_kind = "github"
        source_url = If-Value $Seed.source_url $Repo.html_url
        download_url = If-Value $Seed.download_url "https://api.github.com/repos/$slug/zipball/$defaultBranch"
        license = $license
        last_checked = $Today
        status = "metadata-only"
        notes = Append-Note $Seed.notes "GitHub stars=$($Repo.stargazers_count); $description"
    }
}

function If-Value($Preferred, $Fallback) {
    if ($Preferred) { return $Preferred }
    return $Fallback
}

function New-RowFromSeed($Seed) {
    $slug = Parse-GitHubSlug $Seed.source_url
    $id = $Seed.id
    if (-not $id -and $slug) { $id = "github_$($slug -replace '/', '_')" }
    if (-not $id) { $id = "source_$([Math]::Abs($Seed.source_url.GetHashCode()))" }
    return New-CatalogRow @{
        id = $id
        university = $Seed.university
        aliases = $Seed.aliases
        level = If-Value $Seed.level "unknown"
        template_type = If-Value $Seed.template_type "unknown"
        format = If-Value $Seed.format "unknown"
        source_kind = If-Value $Seed.source_kind (Infer-SourceKind $Seed.source_url)
        source_url = $Seed.source_url
        download_url = $Seed.download_url
        license = If-Value $Seed.license "unknown"
        last_checked = $Today
        status = "metadata-only"
        notes = $Seed.notes
    }
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
    $values["notes"] = Append-Note $Old.notes $New.notes
    if (-not $values["status"]) { $values["status"] = "metadata-only" }
    if (-not $values["last_checked"]) { $values["last_checked"] = $Today }
    return New-CatalogRow $values
}

function Read-CatalogRows([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    return @(Get-Content -Path $Path -Encoding UTF8 | ConvertFrom-Csv)
}

function Read-SeedRows([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    return @(Get-Content -Path $Path -Encoding UTF8 | ConvertFrom-Csv)
}

function Read-Queries([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    return @(Get-Content -Path $Path -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") })
}

function Download-Row($Row) {
    if (-not $Row.download_url) { throw "missing download_url" }
    $slug = Parse-GitHubSlug $Row.source_url
    if (-not $slug) { $slug = $Row.id }
    $base = $slug -replace "/", "__"
    $branch = Safe-Segment (($Row.download_url -split "/")[-1])
    $targetDir = Join-Path $FormatsDir $base
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    $targetPath = Join-Path $targetDir "$base`__$branch.zip"
    if (Test-Path $targetPath) {
        $existing = Get-Item $targetPath
        if ($existing.Length -gt 0) {
            $hash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
            return @{
                local_path = (($targetPath.Substring($SkillRoot.Path.Length + 1)) -replace "\\", "/")
                sha256 = $hash
            }
        }
    }

    $tmpPath = "$targetPath.download"
    if (Test-Path $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force }
    Invoke-WebRequest -Uri $Row.download_url -Headers (Get-GitHubHeaders) -OutFile $tmpPath -TimeoutSec $DownloadTimeoutSec
    Move-Item -LiteralPath $tmpPath -Destination $targetPath -Force
    $hash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    return @{
        local_path = (($targetPath.Substring($SkillRoot.Path.Length + 1)) -replace "\\", "/")
        sha256 = $hash
    }
}

function Write-CatalogRows($Map) {
    $rows = @($Map.Values | Sort-Object id)
    $rows | Select-Object $Fields | Export-Csv -Path $CatalogPath -NoTypeInformation -Encoding UTF8
    return $rows
}

function Search-GitHub([string]$Query, [int]$PerPage) {
    $encoded = [uri]::EscapeDataString($Query)
    $url = "https://api.github.com/search/repositories?q=$encoded&sort=stars&order=desc&per_page=$PerPage"
    $result = Invoke-GitHubJson $url
    return @($result.items)
}

$existing = Read-CatalogRows $CatalogPath
$byId = @{}
$bySource = @{}
foreach ($row in $existing) {
    if ($row.id) { $byId[$row.id] = $row }
    if ($row.source_url) { $bySource[$row.source_url.TrimEnd("/")] = $row }
}

$discovered = @()

if (-not $SearchOnly) {
    foreach ($seed in (Read-SeedRows $SeedPath)) {
        $slug = Parse-GitHubSlug $seed.source_url
        if ($seed.source_kind -eq "github" -and $slug) {
            try {
                $repo = Invoke-GitHubJson "https://api.github.com/repos/$slug"
                $discovered += New-RowFromRepo $repo $seed
            } catch {
                Write-Warning "Seed metadata failed for $($seed.source_url): $($_.Exception.Message)"
                $discovered += New-RowFromSeed $seed
            }
        } else {
            $discovered += New-RowFromSeed $seed
        }
    }
}

if (-not $SeedOnly) {
    foreach ($query in (Read-Queries $QueriesPath)) {
        try {
            foreach ($repo in (Search-GitHub $query $MaxPerQuery)) {
                $discovered += New-RowFromRepo $repo ([pscustomobject]@{})
            }
        } catch {
            Write-Warning "GitHub search failed for '$query': $($_.Exception.Message)"
        }
    }
}

$unique = @{}
foreach ($row in $discovered) {
    if ($row.id -and -not $unique.ContainsKey($row.id)) { $unique[$row.id] = $row }
}

$downloaded = 0
$metadata = 0
$failed = 0

foreach ($incoming in $unique.Values) {
    $old = $null
    if ($incoming.id -and $byId.ContainsKey($incoming.id)) { $old = $byId[$incoming.id] }
    elseif ($incoming.source_url -and $bySource.ContainsKey($incoming.source_url.TrimEnd("/"))) { $old = $bySource[$incoming.source_url.TrimEnd("/")] }
    $merged = Merge-Rows $old $incoming
    if ($MetadataOnly) {
        if ($merged.status -ne "downloaded") { $merged.status = "metadata-only" }
        $metadata += 1
    } else {
        try {
            $result = Download-Row $merged
            $merged.local_path = $result.local_path
            $merged.sha256 = $result.sha256
            $merged.status = "downloaded"
            $downloaded += 1
        } catch {
            $merged.status = If-Value $old.status "failed"
            $merged.notes = Append-Note $merged.notes "download failed: $($_.Exception.Message)"
            $failed += 1
        }
    }
    $merged.last_checked = $Today
    $byId[$merged.id] = $merged
    if ($merged.source_url) { $bySource[$merged.source_url.TrimEnd("/")] = $merged }
    Write-CatalogRows $byId | Out-Null
}

$rows = Write-CatalogRows $byId

Write-Host "catalog: $CatalogPath"
Write-Host "rows: $($rows.Count)"
Write-Host "new/checked: $($unique.Count)"
Write-Host "downloaded: $downloaded"
Write-Host "metadata-only: $metadata"
Write-Host "failed: $failed"




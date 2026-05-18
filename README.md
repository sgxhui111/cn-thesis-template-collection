# CN Thesis Template Collection

[![templates](https://img.shields.io/badge/templates-25-blue)](assets/catalog.csv)
[![universities](https://img.shields.io/badge/universities-20-green)](assets/catalog.csv)
[![formats](https://img.shields.io/badge/formats-LaTeX%20%7C%20Word%20%7C%20PDF-lightgrey)](assets/catalog.csv)
[![GitHub stars](https://img.shields.io/github/stars/sgxhui111/cn-thesis-template-collection?style=social)](https://github.com/sgxhui111/cn-thesis-template-collection)

中国高校毕业论文、学位论文、课程论文格式模板合集。这个项目希望把散落在 GitHub、学校官网、学院通知和同学个人仓库里的模板统一收集、索引、去重，方便后来者少踩一点格式坑。

如果你手里有自己学校的本科毕业论文、硕士/博士学位论文、课程论文、开题报告、答辩 Beamer、Word 模板或 LaTeX 模板，欢迎提交 Issue 或 Pull Request，一起把这个数据库补全。

## 当前收录

截至 2026-05-18，本仓库已收录：

| 类型 | 数量 |
| --- | ---: |
| 模板记录 | 25 |
| 覆盖高校 | 20 |
| LaTeX 模板 | 21 |
| Word 模板 | 2 |
| 混合格式模板 | 2 |
| 已下载归档 | 25 |

完整索引见 [assets/catalog.csv](assets/catalog.csv)。每条记录都尽量保留学校、适用层次、格式、来源、下载地址、本地路径、SHA-256 和许可证信息。

## 院校速览

| 学校/来源 | 层次 | 格式 | 代表来源 |
| --- | --- | --- | --- |
| 中国科学院大学 | 研究生 | LaTeX | [mohuangrui/ucasthesis](https://github.com/mohuangrui/ucasthesis), [xiaoyao9933/UCASthesis](https://github.com/xiaoyao9933/UCASthesis) |
| 华南理工大学 | 本科/研究生 | LaTeX | [mengchaoheng/SCUT_thesis](https://github.com/mengchaoheng/SCUT_thesis), [alwintsui/scutthesis](https://github.com/alwintsui/scutthesis), [OChicken/SCUT-Bachelor-Thesis-Template](https://github.com/OChicken/SCUT-Bachelor-Thesis-Template) |
| 西安交通大学 | 研究生 | LaTeX | [obster-y/XJTU-thesis](https://github.com/obster-y/XJTU-thesis) |
| 华东师范大学 | 本科/硕士/博士 | LaTeX | [Koyamin/ecnuthesis](https://github.com/Koyamin/ecnuthesis) |
| 中国农业大学 | 课程论文 | LaTeX | [Cdmium/CAUTemplate](https://github.com/Cdmium/CAUTemplate) |
| 上海交通大学 | 多层次 | LaTeX | [sjtug/SJTUThesis](https://github.com/sjtug/SJTUThesis) |
| 哈尔滨工业大学 | 多层次 | LaTeX | [hithesis/hithesis](https://github.com/hithesis/hithesis) |
| 北京航空航天大学 | 研究生 | Word + LaTeX | [CheckBoxStudio/BUAAThesis](https://github.com/CheckBoxStudio/BUAAThesis) |
| 南京大学 | 本科/硕士/博士 | LaTeX | [njuhan/njuthesis-nju-thesis-template](https://github.com/njuhan/njuthesis-nju-thesis-template) |
| 南京航空航天大学 | 本科/硕士/博士 | LaTeX | [nuaatug/nuaathesis](https://github.com/nuaatug/nuaathesis) |
| 中国科学技术大学 | 本科/研究生 | LaTeX | [ywgATustcbbs/ustcthesis](https://github.com/ywgATustcbbs/ustcthesis) |
| 电子科技大学 | 未标注 | LaTeX | [bdebye/thesisuestc](https://github.com/bdebye/thesisuestc) |
| 华中科技大学 | 本科 | Word | [miracleyoo/HUST-Grad-Paper-Word-Template](https://github.com/miracleyoo/HUST-Grad-Paper-Word-Template) |
| 四川大学 | 本科 | Word | [SunnyHaze/scu-thesis-template](https://github.com/SunnyHaze/scu-thesis-template) |
| 中山大学 | 本科 | LaTeX | [SYSU-SCC/sysu-thesis](https://github.com/SYSU-SCC/sysu-thesis) |
| 同济大学 | 本科 | LaTeX | [TJ-CSCCG/TongjiThesis](https://github.com/TJ-CSCCG/TongjiThesis) |
| 天津大学 | 研究生 | LaTeX | [a171232886/TJUThesis_master_2021](https://github.com/a171232886/TJUThesis_master_2021) |
| 重庆大学 | 多层次 | LaTeX | [nanmu42/CQUThesis](https://github.com/nanmu42/CQUThesis) |
| 南方科技大学 | 本科 | LaTeX | [iydon/sustechthesis](https://github.com/iydon/sustechthesis) |
| 多校合集 | 多层次 | 多格式 | [hantang/latex-templates](https://github.com/hantang/latex-templates) |

## 如何使用

按学校搜索：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Query-Catalog.ps1 西安交通大学
```

按层次和格式搜索：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Query-Catalog.ps1 -Level undergraduate -Format latex
powershell -ExecutionPolicy Bypass -File scripts\Query-Catalog.ps1 -Level graduate -Format word
```

下载文件统一保存在 `assets/formats/`，索引统一保存在 `assets/catalog.csv`。

## 如何贡献

你可以用两种方式参与。

### 方式一：提交 Issue

适合不熟悉 Git 的同学。请在 Issue 里提供：

| 字段 | 示例 |
| --- | --- |
| 学校 | 华东师范大学 |
| 学院/部门 | 研究生院、本科生院、某学院，未知可写未知 |
| 适用层次 | 本科、硕士、博士、课程论文、开题、答辩 |
| 格式 | Word、LaTeX、PDF、Typst、Beamer |
| 来源链接 | 学校官网、GitHub 仓库、公开下载页 |
| 是否官方 | 官方、学院发布、同学维护、未知 |
| 更新时间 | 2026、2025、未知 |
| 备注 | 编译方式、注意事项、是否有使用说明 |

如果文件只能从学校内网或登录系统下载，请不要直接上传受限文件。可以提交公开说明页面，或说明“需要人工核验”。

### 方式二：提交 Pull Request

适合会 Git 的同学。推荐流程：

1. Fork 本仓库。
2. 添加公开模板文件，推荐路径：`assets/formats/community/学校名或英文缩写/`。
3. 更新 [assets/catalog.csv](assets/catalog.csv)，保留来源 URL、许可证、SHA-256 和说明。
4. 如果来源是 GitHub 仓库，也可以只更新 [assets/sources/seed_sources.csv](assets/sources/seed_sources.csv)，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Collect-GitHubTemplates.ps1 -SeedOnly
```

5. 发起 PR，并在说明里写清楚新增学校、适用层次、来源和是否官方。

## 收录标准

优先收录：

- 学校官网、本科生院、研究生院、学院官网公开发布的模板或格式要求。
- 维护较活跃、来源说明清楚的 GitHub/CTAN/Overleaf 模板。
- 同学自制但有明确学校、适用层次、更新时间和使用说明的模板。

暂不收录：

- 需要绕过登录、验证码、付费墙或内网权限的文件。
- 无法确认学校和适用层次的压缩包。
- 明显侵犯版权、删除原作者署名或许可证的转载文件。

## 数据字段

`assets/catalog.csv` 的核心字段：

| 字段 | 含义 |
| --- | --- |
| `university` | 学校名称 |
| `level` | `undergraduate`、`graduate`、`master`、`doctor`、`multiple`、`unknown` |
| `template_type` | `thesis`、`dissertation`、`proposal`、`defense`、`format-requirement`、`multiple` |
| `format` | `latex`、`word`、`pdf`、`zip`、`multiple`、`unknown` |
| `source_kind` | `official`、`github`、`ctan`、`overleaf`、`other-public` |
| `source_url` | 来源页面 |
| `download_url` | 直接下载地址 |
| `local_path` | 本仓库内保存路径 |
| `sha256` | 文件校验哈希 |
| `license` | 来源许可证 |
| `notes` | 版本、适用范围、风险提示 |

更完整的字段说明见 [references/catalog_schema.md](references/catalog_schema.md)。

## 维护脚本

GitHub 种子源采集：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Collect-GitHubTemplates.ps1 -SeedOnly
```

GitHub 批量搜索采集：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Collect-GitHubTemplates.ps1 -MaxPerQuery 10
```

Google 官方搜索 API 采集：

```powershell
$env:GOOGLE_API_KEY="你的 API Key"
$env:GOOGLE_CSE_ID="你的 Programmable Search Engine ID"
powershell -ExecutionPolicy Bypass -File scripts\Collect-GoogleResults.ps1 -MaxPerQuery 20
```

Google 采集使用官方 Programmable Search JSON API。请不要抓取 Google 搜索结果页面。

## 重要声明

- 本仓库是公开模板和格式要求的索引与备份合集，不代表任何学校官方立场。
- 毕业论文格式会随年份和学院要求变化，提交前请以学校或学院最新通知为准。
- 各模板版权和许可证归原作者或原发布单位所有。本仓库保留来源链接、许可证和哈希，只做整理与可追踪归档。
- 如果你是模板作者或学校相关负责人，希望修改来源说明、删除文件或更新版本，欢迎提交 Issue。

## 参考与致谢

这个项目的 README 和组织方式参考了 [Yuan1z0825/nature-skills](https://github.com/Yuan1z0825/nature-skills) 的索引、安装和贡献说明结构，也感谢各高校模板维护者长期留下的开源工作，尤其是 [mohuangrui/ucasthesis](https://github.com/mohuangrui/ucasthesis)、[mengchaoheng/SCUT_thesis](https://github.com/mengchaoheng/SCUT_thesis)、[obster-y/XJTU-thesis](https://github.com/obster-y/XJTU-thesis)、[Koyamin/ecnuthesis](https://github.com/Koyamin/ecnuthesis)、[Cdmium/CAUTemplate](https://github.com/Cdmium/CAUTemplate)、[alwintsui/scutthesis](https://github.com/alwintsui/scutthesis)、[OChicken/SCUT-Bachelor-Thesis-Template](https://github.com/OChicken/SCUT-Bachelor-Thesis-Template)。

欢迎继续补充你的学校。


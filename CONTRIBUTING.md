# Contributing

感谢你愿意补充高校论文模板。这个仓库希望长期维护，所以每次新增都要做到来源清楚、字段完整、可校验。

## 最简单的贡献方式

如果你不熟悉 Git，可以直接提交 Issue：

1. 打开仓库的 Issues 页面。
2. 选择“提交高校论文模板线索”。
3. 填写学校、层次、格式、公开来源、是否官方、更新时间和备注。

维护者会根据线索补充到 `assets/catalog.csv`。

## Pull Request 方式

适合熟悉 GitHub 的同学。

1. Fork 本仓库。
2. 如果已有公开 GitHub 仓库，优先把仓库信息加入 `assets/sources/seed_sources.csv`。
3. 如果是单独文件，把文件放到 `assets/formats/community/<school-or-abbr>/`。
4. 更新 `assets/catalog.csv`。
5. 运行校验脚本：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Validate-Catalog.ps1 -CheckHashes
```

6. 提交 Pull Request。

## Catalog 必填信息

每条记录至少要尽量填写：

| 字段 | 说明 |
| --- | --- |
| `id` | 稳定唯一 ID |
| `university` | 学校名称 |
| `level` | `undergraduate`、`graduate`、`master`、`doctor`、`multiple`、`unknown` |
| `template_type` | `thesis`、`dissertation`、`proposal`、`defense`、`format-requirement`、`multiple` |
| `format` | `latex`、`word`、`pdf`、`zip`、`multiple`、`unknown` |
| `source_kind` | `official`、`github`、`ctan`、`overleaf`、`other-public` |
| `source_url` | 原始来源链接 |
| `download_url` | 直接下载链接，未知可留空 |
| `local_path` | 仓库中的文件路径，未下载可留空 |
| `sha256` | 文件 SHA-256，未下载可留空 |
| `license` | 许可证，未知写 `unknown` |
| `status` | `downloaded`、`metadata-only`、`failed`、`needs-review` |
| `notes` | 适用年份、适用范围、注意事项 |

## 收录原则

可以收录：

- 学校、本科生院、研究生院或学院官网公开发布的文件。
- 明确说明学校和适用层次的 GitHub、CTAN、Overleaf 模板。
- 同学维护的模板，但要保留原作者、来源链接和许可证。

不要收录：

- 需要登录、内网、验证码、付费权限或绕过访问控制才能获得的文件。
- 无法确认来源、学校或适用层次的文件。
- 删除原作者署名或许可证的转载文件。

## 维护者更新流程

维护者收到 Issue 或 PR 后，可以按这个顺序处理：

```powershell
git pull
powershell -ExecutionPolicy Bypass -File scripts\Collect-GitHubTemplates.ps1 -SeedOnly
powershell -ExecutionPolicy Bypass -File scripts\Validate-Catalog.ps1 -CheckHashes
git add .
git commit -m "Update thesis template collection"
git push
```

如果要用 GitHub 搜索扩展合集：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Collect-GitHubTemplates.ps1 -MaxPerQuery 10
```

如果要用 Google 官方搜索 API 扫学校官网：

```powershell
$env:GOOGLE_API_KEY="your-api-key"
$env:GOOGLE_CSE_ID="your-cse-id"
powershell -ExecutionPolicy Bypass -File scripts\Collect-GoogleResults.ps1 -MaxPerQuery 20
```

## 学术写作和文献功能贡献

欢迎补充新的文献数据库导出格式、字段映射和检索式模板，但请遵守：

- 不添加绕过登录、验证码、付费墙、机构权限或数据库使用条款的代码。
- 不添加规避 AI 检测、规避查重或洗稿功能。
- 新脚本应优先处理用户自己提供的文本、公开元数据或授权数据库导出文件。
- 新增脚本后请运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Validate-Catalog.ps1 -CheckHashes
```

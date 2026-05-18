# Search Query Patterns

## GitHub Search

Use these repository search phrases with `scripts/collect_github_templates.mjs`:

```text
中国 学位论文 模板 LaTeX
高校 学位论文 模板 LaTeX
毕业论文 模板 LaTeX
本科 毕业论文 模板 LaTeX
硕士 博士 学位论文 模板
Chinese university thesis template
China thesis template LaTeX
ctex thesis template university
学位论文 Word 模板
毕业论文 Word 模板
```

## Google Programmable Search

Use the official API for web-scale discovery. Good query patterns:

```text
site:edu.cn 毕业论文 模板 filetype:doc OR filetype:docx
site:edu.cn 毕业论文 格式要求 filetype:pdf
site:edu.cn 学位论文 模板 filetype:doc OR filetype:docx OR filetype:pdf
site:edu.cn 研究生 学位论文 撰写规范 filetype:pdf
site:edu.cn 本科 毕业设计 论文 模板
site:edu.cn 学士学位论文 格式规范
```

For each result, resolve the school name from the domain/page title, download only public files, and add rows to `assets/catalog.csv`.


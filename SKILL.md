---
name: cn-thesis-template-collection
description: Collect, index, search, download, verify, and apply public Chinese university thesis and dissertation formatting templates from GitHub, Overleaf, CTAN, and official university websites. Use when the user asks for Chinese高校毕业论文格式合集, 本科毕业论文模板, 硕士/博士学位论文模板, LaTeX/Word thesis templates, or wants to build/extend a reusable catalog of university thesis formats.
---

# CN Thesis Template Collection

## Core Workflow

Use this skill to maintain a source-grounded collection, not an unverified file dump.

1. Search public sources for thesis/dissertation templates and format requirements.
2. Prefer official university pages first, then well-maintained GitHub/CTAN/Overleaf templates with clear provenance.
3. Download only public files. Do not bypass login, CAPTCHA, paywalls, private repositories, internal school portals, or access controls.
4. Record every item in `assets/catalog.csv` with source URL, school, level, format, license/provenance, local path, hash, and notes.
5. When a user asks for a school's template, search the catalog first with `scripts/query_catalog.mjs`; if missing or stale, run a targeted collection pass and update the catalog.

## Scripts

- `scripts/Collect-GitHubTemplates.ps1`: Windows/PowerShell collector for GitHub seeds and repository search results.
- `scripts/Collect-GoogleResults.ps1`: Windows/PowerShell collector for official/public web results from Google Programmable Search JSON API.
- `scripts/Query-Catalog.ps1`: Windows/PowerShell catalog search.
- `scripts/collect_github_templates.mjs`: Node.js equivalent collector for environments where Node is available.
- `scripts/query_catalog.mjs`: Node.js equivalent catalog search.

Quick commands from this skill folder:

```bash
powershell -ExecutionPolicy Bypass -File scripts/Collect-GitHubTemplates.ps1 -SeedOnly
powershell -ExecutionPolicy Bypass -File scripts/Collect-GitHubTemplates.ps1 -MaxPerQuery 10
powershell -ExecutionPolicy Bypass -File scripts/Collect-GoogleResults.ps1 -MaxPerQuery 20
powershell -ExecutionPolicy Bypass -File scripts/Query-Catalog.ps1 西安交通大学
powershell -ExecutionPolicy Bypass -File scripts/Query-Catalog.ps1 -Level graduate -Format latex
```

Set `GITHUB_TOKEN` for higher GitHub API rate limits. Without a token, keep query batches small.
Set `GOOGLE_API_KEY` and `GOOGLE_CSE_ID` before using Google collection.

## Catalog Rules

Use `references/catalog_schema.md` for field definitions. Keep one row per downloadable artifact or repository archive. If one repository covers multiple degrees or file types, either use `level=multiple`/`format=multiple` or add separate rows when the files are independently useful.

Use `assets/sources/seed_sources.csv` for hand-curated seeds that should always be collected, such as the XJTU template repository.

Use `references/search_queries.md` for reusable GitHub and Google query patterns. For Google-scale collection, use `scripts/Collect-GoogleResults.ps1` with the official Programmable Search JSON API and user-provided API credentials; do not scrape Google result pages.

## Quality Checks

Before recommending a template:

- Check `last_checked` and source URL.
- Prefer rows with `status=downloaded` and a non-empty `sha256`.
- Mention whether the source is official, community-maintained, or inferred from a repository description.
- For school compliance, warn users to compare against the current university/graduate-school rules if the catalog source is not official or is older than two years.

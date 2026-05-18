---
name: cn-thesis-template-collection
description: Collect, index, search, download, verify, and apply public Chinese university thesis and dissertation formatting templates; support ethical Chinese academic writing improvement, originality and repetition-risk review, citation-aware polishing, and literature-search workflows across Web of Science, Scopus, Google Scholar, CNKI, and exported BibTeX/RIS/CSV metadata. Use when the user asks for Chinese高校毕业论文格式合集, 本科毕业论文模板, 硕士/博士学位论文模板, LaTeX/Word thesis templates, 论文降重合规改写, 中文论文润色, 文献检索, or wants to build/extend a reusable catalog for student thesis writing.
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
- `scripts/Invoke-CnOriginalityWorkflow.ps1`: run the full Chinese originality workflow and create a report folder.
- `scripts/Review-CnAcademicText.ps1`: generate a detailed originality, repetition-risk, citation-gap, paragraph-action, and prompt-pack review for a Chinese academic draft.
- `scripts/Review-ChineseAcademicText.ps1`: compatibility wrapper for the older review command.
- `scripts/Compare-CnDrafts.ps1`: compare an original draft and revised draft with Chinese n-gram overlap ratios.
- `scripts/Extract-CnText.ps1`: extract plain text from `.docx`, `.md`, or `.txt` drafts before review.
- `scripts/Build-LiteratureSearch.ps1`: create a lawful multi-database search plan for Web of Science, Scopus, Google Scholar, CNKI, and open metadata sources.
- `scripts/Normalize-LiteratureExport.ps1`: merge user-exported RIS/BibTeX/CSV records into a normalized literature catalog.
- `scripts/collect_github_templates.mjs`: Node.js equivalent collector for environments where Node is available.
- `scripts/query_catalog.mjs`: Node.js equivalent catalog search.

Quick commands from this skill folder:

```bash
powershell -ExecutionPolicy Bypass -File scripts/Collect-GitHubTemplates.ps1 -SeedOnly
powershell -ExecutionPolicy Bypass -File scripts/Collect-GitHubTemplates.ps1 -MaxPerQuery 10
powershell -ExecutionPolicy Bypass -File scripts/Collect-GoogleResults.ps1 -MaxPerQuery 20
powershell -ExecutionPolicy Bypass -File scripts/Query-Catalog.ps1 西安交通大学
powershell -ExecutionPolicy Bypass -File scripts/Query-Catalog.ps1 -Level graduate -Format latex
powershell -ExecutionPolicy Bypass -File scripts/Invoke-CnOriginalityWorkflow.ps1 -InputPath draft.docx -OutputDir review
powershell -ExecutionPolicy Bypass -File scripts/Review-CnAcademicText.ps1 -InputPath draft.md -OutputDir review
powershell -ExecutionPolicy Bypass -File scripts/Review-ChineseAcademicText.ps1 -InputPath draft.md
powershell -ExecutionPolicy Bypass -File scripts/Compare-CnDrafts.ps1 -OriginalPath original.md -RevisedPath revised.md
powershell -ExecutionPolicy Bypass -File scripts/Extract-CnText.ps1 -InputPath thesis.docx -OutputPath thesis.txt
powershell -ExecutionPolicy Bypass -File scripts/Build-LiteratureSearch.ps1 -Query "城市韧性 暴雨 内涝 风险评估" -StartYear 2020 -EndYear 2026
powershell -ExecutionPolicy Bypass -File scripts/Normalize-LiteratureExport.ps1 -InputDir literature-search/exports
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

## Academic Writing Support

Use `references/academic_writing_support.md` before helping with Chinese draft polishing, originality improvement, repetition-risk review, or citation-aware rewriting. For detailed originality workflows, load only the relevant file:

- `references/originality_policy.md`: boundaries when users mention AI rate, AIGC detection, plagiarism rate, CNKI, Turnitin, iThenticate, or "降重".
- `references/originality_revision_workflow.md`: paragraph-by-paragraph diagnosis, evidence request, rewriting, and revision log.
- `references/originality_prompt_templates.md`: safe prompts for rewriting and synthesis.
- `references/citation_and_synthesis.md`: citation-gap and multi-source synthesis rules.

Do not promise to bypass AI detectors, plagiarism systems, CNKI checks, Turnitin, iThenticate, or school integrity review. Reframe those requests as:

- Improve originality by adding the student's own claim, evidence, analysis, and citation trail.
- Reduce repetition risk by replacing copied wording with source-grounded synthesis and proper quotation/citation.
- Polish Chinese academic prose for clarity, structure, terminology, transitions, and argument logic.
- Flag uncited factual claims, template-like filler, duplicate sentences, and overly close paraphrases.

When rewriting, preserve meaning, mark assumptions, ask for sources when needed, and never fabricate citations.

Recommended automatic workflow:

1. Run `scripts/Invoke-CnOriginalityWorkflow.ps1` on the draft.
2. Review `01_originality_report.md`, `02_sentence_issues.csv`, `03_repeated_phrases.csv`, and `04_paragraph_actions.csv`.
3. Rewrite only with the user's claims, data, and sources; mark missing sources as `[需补充来源]`.
4. If a revised draft exists, run `scripts/Compare-CnDrafts.ps1` and use the overlap report as a wording-risk diagnostic, not as a guarantee of passing any detector.

## Literature Search Support

Use `references/literature_search_workflow.md` for database-specific guidance. Web of Science, Scopus, CNKI, and many Google Scholar workflows depend on institutional access, API credentials, or manual export. Do not bypass login, CAPTCHA, paywalls, robot protections, or database terms.

Recommended workflow:

1. Build database-specific search strings with `scripts/Build-LiteratureSearch.ps1`.
2. Let the user run searches in their authorized database accounts.
3. Import exported RIS/BibTeX/CSV files with `scripts/Normalize-LiteratureExport.ps1`.
4. Deduplicate and synthesize the normalized catalog for literature review writing.

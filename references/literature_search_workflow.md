# Literature Search Workflow

This skill supports legal, reproducible literature discovery. It does not bypass institutional subscriptions, paywalls, CAPTCHA, login walls, or database terms.

## Databases

| Database | Best use | Access mode | Export path |
| --- | --- | --- | --- |
| Web of Science | Core international citation index and cited-reference tracing | Institutional account or Clarivate API credentials | RIS, BibTeX, Excel/CSV |
| Scopus | International citation index, abstracts, author/affiliation data | Institutional account or Elsevier API key | RIS, BibTeX, CSV |
| Google Scholar | Broad discovery and citation chasing | Manual search/export or browser-assisted workflow | BibTeX one-by-one or citation-manager import |
| CNKI | Chinese journals, theses, conferences, standards | Institutional/personal account; manual export | RefWorks/RIS-like text, EndNote, GB/T 7714, BibTeX when available |
| Open metadata | Broad public fallback | Crossref/OpenAlex/arXiv/PubMed APIs where applicable | JSON, BibTeX, CSV |

## Search Steps

1. Translate the Chinese topic into field-standard English keywords.
2. Build two query sets: Chinese query for CNKI and bilingual query for international databases.
3. Use `Build-LiteratureSearch.ps1` to create database-specific search strings and a search log template.
4. Run searches in authorized database sessions.
5. Export records to `literature-search/exports`.
6. Run `Normalize-LiteratureExport.ps1` to merge RIS/BibTeX/CSV into `literature_catalog.csv`.
7. Deduplicate by DOI first, then title normalization.
8. Screen titles/abstracts and record inclusion/exclusion decisions.

## Notes

- Web of Science APIs are Clarivate services and require entitlement/API credentials.
- Scopus APIs are Elsevier services and require an API key; some metadata access depends on institutional entitlement.
- Google Scholar does not provide a general public search API. Use manual export or user-authorized reference-manager workflows.
- CNKI automation should use user-exported records or authorized institutional API access only.


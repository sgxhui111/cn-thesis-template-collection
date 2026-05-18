# Catalog Schema

`assets/catalog.csv` is the canonical index for the collection.

Required fields:

- `id`: Stable identifier, usually `github_owner_repo` or a normalized university/source id.
- `university`: Chinese or official English university name when known.
- `aliases`: Pipe-separated aliases, abbreviations, and English names.
- `level`: `undergraduate`, `graduate`, `master`, `doctor`, `multiple`, or `unknown`.
- `template_type`: `thesis`, `dissertation`, `proposal`, `defense`, `format-requirement`, or `multiple`.
- `format`: `latex`, `word`, `pdf`, `html`, `zip`, `multiple`, or `unknown`.
- `source_kind`: `official`, `github`, `ctan`, `overleaf`, or `other-public`.
- `source_url`: Canonical source page.
- `download_url`: Direct downloadable URL when available.
- `local_path`: Path under `assets/formats` after download.
- `sha256`: SHA-256 hash of the downloaded artifact.
- `license`: Source license when known.
- `last_checked`: ISO date when the source was last checked.
- `status`: `downloaded`, `metadata-only`, `failed`, or `needs-review`.
- `notes`: Short provenance, scope, version, or warning.

Conventions:

- Keep source URLs intact. Do not replace official pages with mirror links unless the official page is unavailable.
- Use `needs-review` when the school/level is inferred from repository text rather than confirmed by official documentation.
- Use UTF-8 CSV.
- Deduplicate by normalized source URL first, then by SHA-256.


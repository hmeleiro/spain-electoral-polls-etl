# Spain Electoral Polls

Technical MVP for collecting Spanish national voting intention polls from Wikipedia into PostgreSQL.

The first supported source is the English Wikipedia page `Opinion polling for the next Spanish general election`. The scraper checks the MediaWiki `revision_id`, stores raw page snapshots, parses national voting intention tables, normalizes rows, matches rows against existing polls, and records version history when Wikipedia corrects data.

## Install

Install R dependencies with `renv`:

```r
install.packages("renv")
renv::restore()
```

If you are bootstrapping the lockfile locally, install the required packages from `DESCRIPTION` and run:

```r
renv::snapshot(prompt = FALSE)
```

## Database

Create the database:

```sh
createdb spainelectoralpollsdb
```

Run migrations in order:

```sh
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/001_schema.sql
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/002_indexes.sql
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/003_publication_sources.sql
```

The schema includes `wiki_pages`, `wiki_page_revisions`, `elections`, `pollsters`, `polls`, `poll_results`, `poll_versions`, `poll_identity_events`, and `scraper_runs`. It seeds the MVP election `congreso_espana_2027` and the Wikipedia page `next_spanish_general_election`.

## Configuration

Copy `.env.example` into your runtime environment and set:

```text
PGHOST
PGPORT
PGDATABASE
PGUSER
PGPASSWORD
WIKI_USER_AGENT
```

Use a descriptive `WIKI_USER_AGENT` with contact information for polite Wikipedia access.

## Run

```sh
Rscript scripts/run_scraper.R
```

The default page is `next_spanish_general_election`. To scrape another registered page, set `PAGE_KEY`.

PowerShell example for the 2023 general election polling page:

```powershell
$env:PAGE_KEY = "spanish_general_election_2023"
Rscript scripts/run_scraper.R
$env:PAGE_KEY = "next_spanish_general_election"
```

To reparse the current Wikipedia revision even if it was already marked as processed, for example after parser changes:

```powershell
$env:FORCE_REPROCESS = "true"
Rscript scripts/run_scraper.R
$env:FORCE_REPROCESS = "false"
```

The main function is:

```r
run_poll_scraper(page_key = "next_spanish_general_election")
```

## Revision Detection

Before scraping tables, the pipeline calls the MediaWiki API for the latest revision. If `(page_key, revision_id)` already exists in `wiki_page_revisions` with `parse_status = 'success'`, the run is recorded as `no_change` and no polls are inserted.

For a new revision, the scraper stores raw HTML and wikitext first. This preserves the source snapshot even if parsing fails.

## Poll Identity

`poll_key_strict` is deterministic and uses:

```text
election_key + pollster + media + fieldwork_start + fieldwork_end + sample_size
```

`poll_signature` is more flexible and uses:

```text
election_key + pollster + media + sample_size + publication_date
```

`publication_date` is extracted from the row's Wikipedia citations when available. The parser resolves `cite_note-*` references and reads citation metadata such as `rft.date`, external URL, title, and publisher. `fieldwork_end` is only used as a fallback when no publication date is available from the references.

## Flexible Matching

`match_existing_poll()` first checks `poll_key_strict`. If there is no exact match, it scores candidates with fixed weights for same election, pollster, media, sample size, publication date, fieldwork dates, and similar vote shares.

A single candidate with confidence `>= 0.85` is a `probable_match`. Several close candidates or lower confidence are marked `manual_review`.

## Version History

`row_hash` is built from normalized metadata, dates, sample size, turnout, lead, source, notes, and sorted party results. It detects content changes, not identity.

When an existing poll matches but its `row_hash` changes, the scraper updates `polls`, upserts `poll_results`, inserts a `poll_versions` payload, and records one or more `poll_identity_events`.

Source metadata is stored on `polls` as `source_url`, `source_title`, `source_reference_ids`, and `source_metadata`. This keeps the extracted publication date auditable against the Wikipedia reference used for that row.

At the end of a successful parse, active polls from the same page and election that were not seen in the current revision are marked `is_active = false`. This is used for rows removed from Wikipedia or rows that are now filtered out, such as election-result rows. The scraper records a `poll_missing_from_revision` event instead of deleting data.

## Manual Review

Ambiguous rows are inserted with `identity_status = 'manual_review'`. Review the decision trail with:

```sql
select *
from poll_identity_events
where event_type = 'manual_review'
order by created_at desc;
```

After review, update the affected `polls` row and preserve notes externally or through an additional operational table in a future migration.

## GitHub Actions

`.github/workflows/scrape-polls.yml` runs twice daily and supports manual `workflow_dispatch`. Configure the PostgreSQL and Wikipedia user-agent values as GitHub Secrets.

## Tests

```sh
Rscript -e "testthat::test_dir('tests/testthat')"
```

Tests cover normalization, date parsing, special values, key/signature/hash generation, fixture HTML parsing, correction detection, ambiguity, and low-confidence matching.

## Known MVP Limitations

- Only national voting intention tables from the configured English Wikipedia page are supported.
- Publication date extraction depends on Wikipedia citation metadata; when references lack dates, the scraper falls back to `fieldwork_end`.
- Manual review workflow is auditable but intentionally minimal.
- The parser is tolerant of moderate table changes but still expects recognizable polling, fieldwork, sample, turnout, party, and lead headers.
- PostgreSQL integration requires a reachable database and installed `RPostgres`.

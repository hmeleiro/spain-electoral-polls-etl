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
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/004_manual_review_workflow.sql
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/005_add_november_2019_election.sql
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/006_add_compromis_party.sql
```

The schema includes `wiki_pages`, `wiki_page_revisions`, `elections`, `pollsters`, `parties`, `polls`, `poll_results`, `poll_versions`, `poll_identity_events`, `scraper_runs`, and `poll_review_actions`. It also creates public API helper views: `api_polls_public` and `api_poll_results_public`, plus admin review views for visual moderation.

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

Cron wrapper with daily repo-local logs:

```cron
*/10 * * * * /absolute/path/to/spain-electoral-polls/scripts/run_scraper_cron.sh
```

The wrapper writes to `logs/scraper-{run_id}.log`, updates `logs/latest.log`,
loads `.env` when present, starts from the repository root so `renv` is
activated by `.Rprofile`, and uses `flock` when available to avoid overlapping
scraper runs.

When the scraper processes a new Wikipedia revision successfully, the wrapper
can trigger the downstream poll-of-polls artifact pipeline on the same VM. Set
this in the ETL `.env`:

```text
POLL_OF_POLLS_DATA_DIR=/absolute/path/to/poll-of-polls-data
```

If the scraper records `no_change`, the downstream pipeline is skipped. If the
scraper succeeds with a new revision but `POLL_OF_POLLS_DATA_DIR` is missing or
invalid, the cron wrapper exits with an error so the deployment does not silently
fall behind. The downstream run receives a traceable `RUN_ID` in the form
`wiki-{revision_id}-{timestamp}`.

The default page is `next_spanish_general_election`. To scrape another registered page, set `PAGE_KEY`.

PowerShell example to scrape multiple poll pages:

```powershell
$env:PAGE_KEY = "spanish_general_election_2019_11"
Rscript scripts/run_scraper.R
$env:PAGE_KEY = "spanish_general_election_2023_2019_2021"
Rscript scripts/run_scraper.R
$env:PAGE_KEY = "spanish_general_election_2023_2022"
Rscript scripts/run_scraper.R
$env:PAGE_KEY = "spanish_general_election_2023"
Rscript scripts/run_scraper.R
$env:PAGE_KEY = "next_spanish_general_election"
Rscript scripts/run_scraper.R
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

## Deploy

Pushing to GitHub deploys the ETL repository to:

```text
/home/deploy/spain-electoral-polls-etl/
```

Configure these repository secrets in GitHub Actions:

```text
DEPLOY_HOST
DEPLOY_SSH_KEY
```

Optional secrets:

```text
DEPLOY_USER      # defaults to deploy
DEPLOY_SSH_PORT  # defaults to 22
```

The deploy uses `rsync` over SSH, preserves runtime files such as `.env`,
`logs/*.log`, `.scraper.lock`, and `renv/library/`, then makes
`scripts/run_scraper_cron.sh` executable on the remote machine.

## Revision Detection

Before scraping tables, the pipeline calls the MediaWiki API for the latest revision. If `(page_key, revision_id)` already exists in `wiki_page_revisions` with `parse_status = 'success'`, the run is recorded as `no_change` and no polls are inserted.

For a new revision, the scraper stores raw HTML and wikitext first. This preserves the source snapshot even if parsing fails.

## Poll Identity

`poll_key_strict` is deterministic and uses:

```text
election_key + pollster + media + fieldwork_start + fieldwork_end + sample_size
```

Rows with an explicit poll variant append variant metadata to the strict key. For example, Wikipedia rows labelled `CIS (Ateneo del Dato)` or `CIS (LogosLab)` with the note `Alternative projection based on raw CIS data.` are normalized as:

```text
pollster = Ateneo del Dato / LogosLab / ...
media = CIS
poll_variant = reestimate
base_pollster_key = cis
base_data_source_key = cis
```

The relationship with the source poll is stored in `source_metadata`, so the reestimate is kept as a separate poll even when it shares CIS fieldwork dates and sample size.

`poll_signature` is more flexible and uses:

```text
election_key + pollster + media + sample_size + publication_date
```

`publication_date` is extracted from the row's Wikipedia citations when available. The parser resolves `cite_note-*` references and reads citation metadata such as `rft.date`, external URL, title, and publisher. `fieldwork_end` is only used as a fallback when no publication date is available from the references.

## Flexible Matching

`match_existing_poll()` first checks `poll_key_strict`. If there is no exact match, it scores candidates with fixed weights for same election, pollster, media, sample size, publication date, fieldwork dates, and identical vote shares across the comparable party subset.

Fuzzy candidates from a different pollster are capped below the candidate threshold. This prevents reestimates or other derived series from being sent to manual review just because they reuse the source poll's dates.

A single candidate with confidence `>= 0.85` is a `probable_match`. Several close candidates or lower confidence are marked `manual_review`.

## Version History

`row_hash` is built from normalized metadata, dates, sample size, turnout, lead, source, notes, and sorted party results. It detects content changes, not identity.

When an existing poll matches but its `row_hash` changes, the scraper updates `polls`, upserts `poll_results`, inserts a `poll_versions` payload, and records one or more `poll_identity_events`.

Source metadata is stored on `polls` as `source_url`, `source_title`, `source_reference_ids`, and `source_metadata`. This keeps the extracted publication date auditable against the Wikipedia reference used for that row.

## Public SQL Views

For API and dashboard reads, prefer:

```sql
select * from api_polls_public limit 5;
select * from api_poll_results_public limit 5;
select * from parties order by display_order;
```

The public views already filter out inactive polls and `manual_review` rows.

At the end of a successful parse, active polls from the same page and election that were not seen in the current revision are marked `is_active = false`. This is used for rows removed from Wikipedia or rows that are now filtered out, such as election-result rows. The scraper records a `poll_missing_from_revision` event instead of deleting data.

## Manual Review

Ambiguous rows are inserted with `identity_status = 'manual_review'`. For visual admin review, use:

```sql
select * from admin_poll_review_queue limit 50;
select * from admin_poll_review_detail where poll_id = 202;
select * from admin_poll_review_results where poll_id = 202;
```

`admin_poll_review_queue` is designed for a review inbox. It includes priority, latest review status, anomaly counts, vote-share sum, source labels, matching confidence, and a JSON `anomalies` array that can be rendered as badges.

`admin_poll_review_detail` is designed for the poll detail screen. It includes metadata, source audit fields, latest matching event, latest normalized payload, anomaly JSON, and result JSON. `admin_poll_review_results` provides one row per party with party colors and deltas against recent comparable polls.

Review decisions are persisted in `poll_review_actions`. From R, use:

```r
queue <- list_manual_review_polls(con, limit = 50)
poll <- get_manual_review_poll(con, poll_id = 202)
record_poll_review_decision(con, 202, "approved_new_poll", reviewer = "admin@example.com")
```

Supported actions are `approved_new_poll`, `approved_match`, `rejected`, `needs_fix`, and `comment`.

## Tests

```sh
Rscript -e "testthat::test_dir('tests/testthat')"
```

Tests cover normalization, date parsing, special values, key/signature/hash generation, fixture HTML parsing, correction detection, ambiguity, and low-confidence matching.

## Known MVP Limitations

- Only national voting intention tables from the configured English Wikipedia page are supported.
- Publication date extraction depends on Wikipedia citation metadata; when references lack dates, the scraper falls back to `fieldwork_end`.
- The parser is tolerant of moderate table changes but still expects recognizable polling, fieldwork, sample, turnout, party, and lead headers.
- PostgreSQL integration requires a reachable database and installed `RPostgres`.

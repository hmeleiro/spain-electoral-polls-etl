create index if not exists idx_wiki_page_revisions_page_revision
  on wiki_page_revisions (page_key, revision_id);

create index if not exists idx_wiki_page_revisions_status
  on wiki_page_revisions (parse_status);

create index if not exists idx_polls_election_page
  on polls (election_id, wiki_page);

create index if not exists idx_polls_public_filters
  on polls (election_id, is_active, identity_status, fieldwork_end desc, publication_date desc);

create index if not exists idx_polls_pollster
  on polls (pollster_id);

create index if not exists idx_polls_media
  on polls (media);

create index if not exists idx_polls_signature
  on polls (poll_signature);

create index if not exists idx_polls_row_hash
  on polls (row_hash);

create index if not exists idx_polls_publication_date
  on polls (publication_date);

create index if not exists idx_polls_source_metadata
  on polls using gin (source_metadata);

create index if not exists idx_poll_results_party
  on poll_results (party_key);

create index if not exists idx_poll_versions_poll
  on poll_versions (poll_id, valid_from desc);

create index if not exists idx_poll_identity_events_poll
  on poll_identity_events (poll_id, created_at desc);

create index if not exists idx_scraper_runs_page_started
  on scraper_runs (page_key, started_at desc);

create table if not exists elections (
  id bigserial primary key,
  election_key text not null unique,
  election_type text not null,
  territory_code text not null,
  election_name text not null,
  election_date date,
  created_at timestamptz not null default now()
);

create table if not exists wiki_pages (
  id bigserial primary key,
  page_key text not null unique,
  page_title text not null,
  url text not null,
  election_key text not null references elections(election_key),
  territory_code text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists wiki_page_revisions (
  id bigserial primary key,
  page_key text not null references wiki_pages(page_key),
  revision_id bigint not null,
  revision_timestamp timestamptz,
  fetched_at timestamptz not null default now(),
  content_sha256 text,
  raw_html text,
  raw_wikitext text,
  parse_status text not null default 'fetched'
    check (parse_status in ('fetched', 'success', 'failed')),
  error_message text,
  unique (page_key, revision_id)
);

create table if not exists pollsters (
  id bigserial primary key,
  pollster_name text not null,
  pollster_key text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists polls (
  id bigserial primary key,
  poll_key_strict text not null unique,
  poll_signature text not null,
  election_id bigint not null references elections(id),
  pollster_id bigint not null references pollsters(id),
  media text,
  fieldwork_start date,
  fieldwork_end date,
  publication_date date,
  sample_size integer,
  turnout numeric,
  lead numeric,
  wiki_page text not null references wiki_pages(page_key),
  wiki_revision_id bigint,
  source_url text,
  source_title text,
  source_reference_ids jsonb not null default '[]'::jsonb,
  source_metadata jsonb not null default '{}'::jsonb,
  row_hash text not null,
  identity_status text not null
    check (identity_status in ('exact', 'probable_match', 'manual_review', 'new_poll')),
  identity_confidence numeric,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true
);

create table if not exists poll_results (
  id bigserial primary key,
  poll_id bigint not null references polls(id) on delete cascade,
  party_key text not null,
  party_raw text,
  vote_share numeric,
  seats_min integer,
  seats_max integer,
  raw_value text,
  unique (poll_id, party_key)
);

create table if not exists poll_versions (
  id bigserial primary key,
  poll_id bigint not null references polls(id) on delete cascade,
  wiki_revision_id bigint,
  row_hash text not null,
  payload_json jsonb not null,
  valid_from timestamptz not null default now()
);

create table if not exists poll_identity_events (
  id bigserial primary key,
  poll_id bigint references polls(id),
  wiki_revision_id bigint,
  event_type text not null,
  old_payload jsonb,
  new_payload jsonb,
  confidence numeric,
  reasons jsonb,
  created_at timestamptz not null default now()
);

create table if not exists scraper_runs (
  id bigserial primary key,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null
    check (status in ('running', 'success', 'failed', 'no_change')),
  page_key text references wiki_pages(page_key),
  revision_id bigint,
  rows_found integer default 0,
  polls_inserted integer default 0,
  polls_updated integer default 0,
  polls_unchanged integer default 0,
  polls_manual_review integer default 0,
  error_message text
);

insert into elections (election_key, election_type, territory_code, election_name, election_date)
values ('congreso_espana_2027', 'general', 'ES', 'Next Spanish general election', null)
on conflict (election_key) do update set
  election_type = excluded.election_type,
  territory_code = excluded.territory_code,
  election_name = excluded.election_name,
  election_date = excluded.election_date;

insert into elections (election_key, election_type, territory_code, election_name, election_date)
values ('congreso_espana_2023', 'general', 'ES', '2023 Spanish general election', '2023-07-23')
on conflict (election_key) do update set
  election_type = excluded.election_type,
  territory_code = excluded.territory_code,
  election_name = excluded.election_name,
  election_date = excluded.election_date;

insert into wiki_pages (page_key, page_title, url, election_key, territory_code, is_active)
values (
  'next_spanish_general_election',
  'Opinion polling for the next Spanish general election',
  'https://en.wikipedia.org/wiki/Opinion_polling_for_the_next_Spanish_general_election',
  'congreso_espana_2027',
  'ES',
  true
)
on conflict (page_key) do update set
  page_title = excluded.page_title,
  url = excluded.url,
  election_key = excluded.election_key,
  territory_code = excluded.territory_code,
  is_active = excluded.is_active;

insert into wiki_pages (page_key, page_title, url, election_key, territory_code, is_active)
values (
  'spanish_general_election_2023',
  'Opinion polling for the 2023 Spanish general election',
  'https://en.wikipedia.org/wiki/Opinion_polling_for_the_2023_Spanish_general_election',
  'congreso_espana_2023',
  'ES',
  true
)
on conflict (page_key) do update set
  page_title = excluded.page_title,
  url = excluded.url,
  election_key = excluded.election_key,
  territory_code = excluded.territory_code,
  is_active = excluded.is_active;

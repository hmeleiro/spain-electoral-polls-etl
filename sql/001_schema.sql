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

create table if not exists parties (
  party_key text primary key,
  party_name text not null,
  short_name text not null,
  territory_code text not null default 'ES',
  color_hex text,
  display_order integer,
  is_active boolean not null default true,
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

create table if not exists poll_review_actions (
  id bigserial primary key,
  poll_id bigint not null references polls(id) on delete cascade,
  action text not null
    check (action in ('approved_new_poll', 'approved_match', 'rejected', 'needs_fix', 'comment')),
  previous_identity_status text,
  new_identity_status text,
  reviewer text,
  notes text,
  corrected_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists poll_match_candidates (
  id bigserial primary key,
  poll_id bigint not null references polls(id) on delete cascade,
  candidate_poll_id bigint not null references polls(id) on delete cascade,
  wiki_revision_id bigint,
  rank integer not null,
  confidence numeric,
  reasons jsonb not null default '[]'::jsonb,
  candidate_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

insert into elections (election_key, election_type, territory_code, election_name, election_date)
values ('congreso_espana_2026', 'general', 'ES', '2026 Spanish general election', '2026-11-29')
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

insert into elections (election_key, election_type, territory_code, election_name, election_date)
values ('congreso_espana_2019_11', 'general', 'ES', 'November 2019 Spanish general election', '2019-11-10')
on conflict (election_key) do update set
  election_type = excluded.election_type,
  territory_code = excluded.territory_code,
  election_name = excluded.election_name,
  election_date = excluded.election_date;

insert into wiki_pages (page_key, page_title, url, election_key, territory_code, is_active)
values (
  'next_spanish_general_election',
  'Opinion polling for the 2026 Spanish general election',
  'https://en.wikipedia.org/wiki/Opinion_polling_for_the_2026_Spanish_general_election',
  'congreso_espana_2026',
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
  'spanish_general_election_2019_11',
  'Opinion polling for the November 2019 Spanish general election',
  'https://en.wikipedia.org/wiki/Opinion_polling_for_the_November_2019_Spanish_general_election',
  'congreso_espana_2019_11',
  'ES',
  true
)
on conflict (page_key) do update set
  page_title = excluded.page_title,
  url = excluded.url,
  election_key = excluded.election_key,
  territory_code = excluded.territory_code,
  is_active = excluded.is_active;

insert into parties
  (party_key, party_name, short_name, territory_code, color_hex, display_order, is_active)
values
  ('psoe', 'Partido Socialista Obrero Espanol', 'PSOE', 'ES', '#e30613', 10, true),
  ('pp', 'Partido Popular', 'PP', 'ES', '#1d84ce', 20, true),
  ('vox', 'Vox', 'Vox', 'ES', '#63be21', 30, true),
  ('fa', 'Frente Amplio', 'FA', 'ES', null, 35, true),
  ('fv', 'Compromís–Front Valencià', 'FV', 'ES-VC', null, 36, true),
  ('sumar', 'Sumar', 'Sumar', 'ES', '#e51b7e', 40, true),
  ('podemos', 'Podemos', 'Podemos', 'ES', '#6f2c91', 50, true),
  ('cs', 'Ciudadanos', 'Cs', 'ES', '#eb6109', 60, true),
  ('erc', 'Esquerra Republicana de Catalunya', 'ERC', 'ES-CT', '#f3b217', 70, true),
  ('junts', 'Junts per Catalunya', 'Junts', 'ES-CT', '#00a6a6', 80, true),
  ('eh_bildu', 'EH Bildu', 'EH Bildu', 'ES-PV', '#b5c800', 90, true),
  ('eaj_pnv', 'EAJ/PNV', 'PNV', 'ES-PV', '#00843d', 100, true),
  ('bng', 'Bloque Nacionalista Galego', 'BNG', 'ES-GA', '#76b82a', 110, true),
  ('cup', 'Candidatura d''Unitat Popular', 'CUP', 'ES-CT', '#ffed00', 120, true),
  ('cca', 'Coalicion Canaria', 'CCa', 'ES-CN', '#f6c915', 130, true),
  ('upn', 'Union del Pueblo Navarro', 'UPN', 'ES-NC', '#005baa', 140, true),
  ('na', 'Navarra Suma', 'NA+', 'ES-NC', '#005baa', 140, true),
  ('prc', 'Partido Regionalista de Cantabria', 'PRC', 'ES-CB', '#c8102e', 150, true),
  ('ev', 'Espana Vaciada', 'EV', 'ES', '#8f8f8f', 160, true),
  ('mas_pais', 'Mas Pais', 'MP', 'ES', '#14b8a6', 170, true),
  ('compromis', 'Compromís', 'Compromís', 'ES-VC', '#f39128', 175, true),
  ('pacma', 'PACMA', 'PACMA', 'ES', '#7ac143', 180, true),
  ('adelante_andalucia', 'Adelante Andalucia', 'AA', 'ES-AN', '#00a3ad', 190, true),
  ('salf', 'Se Acabo La Fiesta', 'SALF', 'ES', '#5d6470', 200, true),
  ('alianca_cat', 'Alianca Catalana', 'AC', 'ES-CT', '#2f80ed', 210, true),
  ('te', 'Teruel Existe', 'TE', 'ES-AR', '#007B4D', 212, true),
  ('others', 'Others', 'Others', 'ES', null, 999, true)
on conflict (party_key) do update set
  party_name = excluded.party_name,
  short_name = excluded.short_name,
  territory_code = excluded.territory_code,
  color_hex = excluded.color_hex,
  display_order = excluded.display_order,
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

insert into wiki_pages (page_key, page_title, url, election_key, territory_code, is_active)
values (
  'spanish_general_election_2023_2022',
  'Nationwide opinion polling for the 2023 Spanish general election (2022)',
  'https://en.wikipedia.org/wiki/Nationwide_opinion_polling_for_the_2023_Spanish_general_election_(2022)',
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

insert into wiki_pages (page_key, page_title, url, election_key, territory_code, is_active)
values (
  'spanish_general_election_2023_2019_2021',
  'Nationwide opinion polling for the 2023 Spanish general election (2019-2021)',
  'https://en.wikipedia.org/wiki/Nationwide_opinion_polling_for_the_2023_Spanish_general_election_(2019%E2%80%932021)',
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

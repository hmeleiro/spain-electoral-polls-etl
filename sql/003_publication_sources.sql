alter table polls
  add column if not exists source_title text;

alter table polls
  add column if not exists source_reference_ids jsonb not null default '[]'::jsonb;

alter table polls
  add column if not exists source_metadata jsonb not null default '{}'::jsonb;

create index if not exists idx_polls_publication_date
  on polls (publication_date);

create index if not exists idx_polls_source_metadata
  on polls using gin (source_metadata);

begin;

insert into wiki_pages
  (page_key, page_title, url, election_key, territory_code, is_active)
values (
  'next_spanish_general_election_2023_2024',
  'Nationwide opinion polling for the 2026 Spanish general election (2023–2024)',
  'https://en.wikipedia.org/wiki/Nationwide_opinion_polling_for_the_2026_Spanish_general_election_(2023%E2%80%932024)',
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

commit;

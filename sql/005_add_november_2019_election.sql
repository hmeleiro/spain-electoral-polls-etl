insert into elections (election_key, election_type, territory_code, election_name, election_date)
values ('congreso_espana_2019_11', 'general', 'ES', 'November 2019 Spanish general election', '2019-11-10')
on conflict (election_key) do update set
  election_type = excluded.election_type,
  territory_code = excluded.territory_code,
  election_name = excluded.election_name,
  election_date = excluded.election_date;

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

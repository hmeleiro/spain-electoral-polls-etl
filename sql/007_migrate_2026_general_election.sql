begin;

insert into elections
  (election_key, election_type, territory_code, election_name, election_date)
values
  ('congreso_espana_2026', 'general', 'ES', '2026 Spanish general election', '2026-11-29')
on conflict (election_key) do update set
  election_type = excluded.election_type,
  territory_code = excluded.territory_code,
  election_name = excluded.election_name,
  election_date = excluded.election_date;

do $migration$
declare
  old_election_id bigint;
  new_election_id bigint;
begin
  select id
    into old_election_id
    from elections
   where election_key = 'congreso_espana_2027';

  select id
    into strict new_election_id
    from elections
   where election_key = 'congreso_espana_2026';

  if old_election_id is not null and old_election_id <> new_election_id then
    update wiki_pages
       set election_key = 'congreso_espana_2026'
     where election_key = 'congreso_espana_2027';

    update polls
       set election_id = new_election_id
     where election_id = old_election_id;

    delete from elections
     where id = old_election_id;
  end if;
end
$migration$;

update polls
   set poll_key_strict = 'congreso_espana_2026' ||
         substr(poll_key_strict, length('congreso_espana_2027') + 1)
 where left(poll_key_strict, length('congreso_espana_2027')) = 'congreso_espana_2027';

update polls
   set poll_signature = 'congreso_espana_2026' ||
         substr(poll_signature, length('congreso_espana_2027') + 1)
 where left(poll_signature, length('congreso_espana_2027')) = 'congreso_espana_2027';

insert into wiki_pages
  (page_key, page_title, url, election_key, territory_code, is_active)
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

insert into parties
  (party_key, party_name, short_name, territory_code, color_hex, display_order, is_active)
values
  ('fa', 'Frente Amplio', 'FA', 'ES', null, 35, true),
  ('fv', 'Compromís–Front Valencià', 'FV', 'ES-VC', null, 36, true)
on conflict (party_key) do update set
  party_name = excluded.party_name,
  short_name = excluded.short_name,
  territory_code = excluded.territory_code,
  color_hex = coalesce(excluded.color_hex, parties.color_hex),
  display_order = excluded.display_order,
  is_active = excluded.is_active;

commit;

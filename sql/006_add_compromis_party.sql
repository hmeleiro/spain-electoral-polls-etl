insert into parties
  (party_key, party_name, short_name, territory_code, color_hex, display_order, is_active)
values
  ('compromis', 'Compromís', 'Compromís', 'ES-VC', '#f39128', 175, true)
on conflict (party_key) do update set
  party_name = excluded.party_name,
  short_name = excluded.short_name,
  territory_code = excluded.territory_code,
  color_hex = excluded.color_hex,
  display_order = excluded.display_order,
  is_active = excluded.is_active;

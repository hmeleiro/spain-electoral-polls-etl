insert into parties
  (party_key, party_name, short_name, territory_code, color_hex, display_order, is_active)
values
  ('fa_fv', 'Frente Amplio–Front Valencià', 'FA–FV', 'ES', null, 35, true)
on conflict (party_key) do update set
  party_name = excluded.party_name,
  short_name = excluded.short_name,
  territory_code = excluded.territory_code,
  color_hex = coalesce(excluded.color_hex, parties.color_hex),
  display_order = excluded.display_order,
  is_active = excluded.is_active;

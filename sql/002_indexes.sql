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

create index if not exists idx_parties_display_order
  on parties (is_active, display_order, party_key);

create index if not exists idx_poll_versions_poll
  on poll_versions (poll_id, valid_from desc);

create index if not exists idx_poll_identity_events_poll
  on poll_identity_events (poll_id, created_at desc);

create index if not exists idx_scraper_runs_page_started
  on scraper_runs (page_key, started_at desc);

create index if not exists idx_poll_review_actions_poll_created
  on poll_review_actions (poll_id, created_at desc, id desc);

create index if not exists idx_poll_review_actions_action_created
  on poll_review_actions (action, created_at desc);

create index if not exists idx_poll_match_candidates_poll_revision
  on poll_match_candidates (poll_id, wiki_revision_id, rank);

create index if not exists idx_poll_match_candidates_candidate
  on poll_match_candidates (candidate_poll_id);

create or replace view api_polls_public as
select
  p.id as poll_id,
  e.election_key,
  e.election_type,
  e.territory_code,
  e.election_name,
  e.election_date,
  ps.pollster_key,
  ps.pollster_name,
  p.media,
  p.fieldwork_start,
  p.fieldwork_end,
  p.publication_date,
  p.sample_size,
  p.turnout,
  p.lead,
  p.source_url,
  p.source_title,
  p.identity_status,
  p.first_seen_at,
  p.updated_at,
  p.is_active
from polls p
join elections e on e.id = p.election_id
join pollsters ps on ps.id = p.pollster_id
where p.is_active = true
  and p.identity_status <> 'manual_review';

create or replace view admin_poll_review_anomalies as
select
  p.id as poll_id,
  'warning'::text as severity,
  'manual_review_status'::text as anomaly_code,
  'La encuesta esta marcada para revision manual.'::text as message
from polls p
where p.identity_status = 'manual_review'

union all

select
  p.id,
  'warning',
  'inactive_poll',
  'La encuesta esta inactiva o ya no aparece en la fuente actual.'
from polls p
where p.is_active = false

union all

select
  p.id,
  'warning',
  'low_identity_confidence',
  'La confianza del matching esta por debajo de 0.85.'
from polls p
where p.identity_confidence is not null
  and p.identity_confidence < 0.85

union all

select
  p.id,
  'error',
  'missing_fieldwork_dates',
  'Faltan fechas de trabajo de campo.'
from polls p
where p.fieldwork_start is null
   or p.fieldwork_end is null

union all

select
  p.id,
  'error',
  'fieldwork_after_publication',
  'La fecha de campo termina despues de la fecha de publicacion.'
from polls p
where p.fieldwork_end is not null
  and p.publication_date is not null
  and p.fieldwork_end > p.publication_date

union all

select
  p.id,
  'warning',
  'missing_sample_size',
  'Falta el tamano muestral.'
from polls p
where p.sample_size is null

union all

select
  p.id,
  'info',
  'missing_source_url',
  'No hay URL externa de fuente; revisar metadatos de referencia.'
from polls p
where p.source_url is null
   or trim(p.source_url) = ''

union all

select distinct
  p.id,
  'error',
  'unknown_party',
  'Hay resultados asociados a partidos no catalogados.'
from polls p
join poll_results pr on pr.poll_id = p.id
left join parties pa on pa.party_key = pr.party_key
where pa.party_key is null

union all

select distinct
  p.id,
  'error',
  'vote_share_out_of_range',
  'Hay porcentajes de voto fuera del rango 0-100.'
from polls p
join poll_results pr on pr.poll_id = p.id
where pr.vote_share < 0
   or pr.vote_share > 100

union all

select
  totals.poll_id,
  'warning',
  'vote_share_sum_low',
  'La suma de porcentajes esta por debajo de 75.'
from (
  select poll_id, sum(vote_share) as vote_share_sum
  from poll_results
  where vote_share is not null
  group by poll_id
) totals
where totals.vote_share_sum < 75

union all

select
  totals.poll_id,
  'warning',
  'vote_share_sum_high',
  'La suma de porcentajes supera 105.'
from (
  select poll_id, sum(vote_share) as vote_share_sum
  from poll_results
  where vote_share is not null
  group by poll_id
) totals
where totals.vote_share_sum > 105;

create or replace view admin_poll_review_results as
select
  pr.poll_id,
  pr.party_key,
  pr.party_raw,
  coalesce(pa.party_name, pr.party_raw) as party_name,
  coalesce(pa.short_name, pr.party_raw) as short_name,
  pa.color_hex,
  pa.display_order,
  pa.party_key is null as is_unknown_party,
  pr.vote_share,
  pr.seats_min,
  pr.seats_max,
  pr.raw_value,
  recent.recent_average_vote_share,
  case
    when pr.vote_share is null or recent.recent_average_vote_share is null then null
    else pr.vote_share - recent.recent_average_vote_share
  end as delta_from_recent_average
from poll_results pr
join polls p on p.id = pr.poll_id
left join parties pa on pa.party_key = pr.party_key
left join lateral (
  select round(avg(pr2.vote_share), 2) as recent_average_vote_share
  from (
    select p2.id
    from polls p2
    where p2.election_id = p.election_id
      and p2.id <> p.id
      and p2.is_active = true
      and p2.identity_status <> 'manual_review'
      and coalesce(p2.fieldwork_end, p2.publication_date) <= coalesce(p.fieldwork_end, p.publication_date, now()::date)
    order by coalesce(p2.fieldwork_end, p2.publication_date) desc nulls last, p2.id desc
    limit 10
  ) recent_polls
  join poll_results pr2 on pr2.poll_id = recent_polls.id
  where pr2.party_key = pr.party_key
    and pr2.vote_share is not null
) recent on true;

create or replace view admin_poll_review_match_candidates as
select
  pmc.poll_id,
  pmc.candidate_poll_id,
  pmc.wiki_revision_id,
  pmc.rank,
  pmc.confidence,
  pmc.reasons,
  pmc.candidate_snapshot,
  pmc.candidate_snapshot->>'pollster_key' as pollster_key,
  pmc.candidate_snapshot->>'pollster_name' as pollster_name,
  pmc.candidate_snapshot->>'media' as media,
  (pmc.candidate_snapshot->>'fieldwork_start')::date as fieldwork_start,
  (pmc.candidate_snapshot->>'fieldwork_end')::date as fieldwork_end,
  (pmc.candidate_snapshot->>'publication_date')::date as publication_date,
  (pmc.candidate_snapshot->>'sample_size')::integer as sample_size,
  pmc.candidate_snapshot->>'source_url' as source_url,
  pmc.candidate_snapshot->>'source_title' as source_title,
  pmc.candidate_snapshot->>'identity_status' as identity_status,
  (pmc.candidate_snapshot->>'vote_share_sum')::numeric as vote_share_sum,
  coalesce(pmc.candidate_snapshot->'results', '[]'::jsonb) as results,
  pmc.created_at
from poll_match_candidates pmc;

create or replace view admin_poll_review_detail as
with latest_action as (
  select distinct on (poll_id)
    poll_id,
    action,
    reviewer,
    notes,
    created_at
  from poll_review_actions
  order by poll_id, created_at desc, id desc
),
latest_event as (
  select distinct on (poll_id)
    poll_id,
    event_type,
    confidence,
    reasons,
    created_at
  from poll_identity_events
  where poll_id is not null
  order by poll_id, created_at desc, id desc
),
latest_version as (
  select distinct on (poll_id)
    poll_id,
    wiki_revision_id,
    payload_json,
    valid_from
  from poll_versions
  order by poll_id, valid_from desc, id desc
),
anomaly_summary as (
  select
    poll_id,
    count(*) as anomaly_count,
    count(*) filter (where severity = 'error') as error_count,
    count(*) filter (where severity = 'warning') as warning_count,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'severity', severity,
          'code', anomaly_code,
          'message', message
        )
        order by
          case severity when 'error' then 1 when 'warning' then 2 else 3 end,
          anomaly_code
      ),
      '[]'::jsonb
    ) as anomalies
  from admin_poll_review_anomalies
  group by poll_id
),
result_summary as (
  select
    poll_id,
    count(*) as result_count,
    round(sum(vote_share) filter (where vote_share is not null), 2) as vote_share_sum,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'party_key', party_key,
          'party_raw', party_raw,
          'party_name', party_name,
          'short_name', short_name,
          'color_hex', color_hex,
          'is_unknown_party', is_unknown_party,
          'vote_share', vote_share,
          'seats_min', seats_min,
          'seats_max', seats_max,
          'raw_value', raw_value,
          'recent_average_vote_share', recent_average_vote_share,
          'delta_from_recent_average', delta_from_recent_average
        )
        order by display_order nulls last, party_key
      ),
      '[]'::jsonb
    ) as results
  from admin_poll_review_results
  group by poll_id
),
candidate_summary as (
  select
    poll_id,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'candidate_poll_id', candidate_poll_id,
          'rank', rank,
          'confidence', confidence,
          'reasons', reasons,
          'pollster_key', pollster_key,
          'pollster_name', pollster_name,
          'media', media,
          'fieldwork_start', fieldwork_start,
          'fieldwork_end', fieldwork_end,
          'publication_date', publication_date,
          'sample_size', sample_size,
          'source_url', source_url,
          'source_title', source_title,
          'identity_status', identity_status,
          'vote_share_sum', vote_share_sum,
          'results', results
        )
        order by rank
      ),
      '[]'::jsonb
    ) as match_candidates
  from admin_poll_review_match_candidates
  group by poll_id
)
select
  p.id as poll_id,
  e.election_key,
  e.election_type,
  e.territory_code,
  e.election_name,
  ps.pollster_key,
  ps.pollster_name,
  p.media,
  p.fieldwork_start,
  p.fieldwork_end,
  p.publication_date,
  p.sample_size,
  p.turnout,
  p.lead,
  p.wiki_page,
  wp.page_title as wiki_page_title,
  wp.url as wiki_page_url,
  p.wiki_revision_id,
  p.source_url,
  p.source_title,
  p.source_reference_ids,
  p.source_metadata,
  p.identity_status,
  p.identity_confidence,
  p.first_seen_at,
  p.last_seen_at,
  p.updated_at,
  p.is_active,
  coalesce(rs.result_count, 0) as result_count,
  rs.vote_share_sum,
  coalesce(rs.results, '[]'::jsonb) as results,
  coalesce(ans.anomaly_count, 0) as anomaly_count,
  coalesce(ans.error_count, 0) as error_count,
  coalesce(ans.warning_count, 0) as warning_count,
  coalesce(ans.anomalies, '[]'::jsonb) as anomalies,
  le.event_type as latest_identity_event_type,
  le.confidence as latest_identity_event_confidence,
  le.reasons as latest_identity_event_reasons,
  le.created_at as latest_identity_event_at,
  lv.payload_json as latest_payload_json,
  lv.valid_from as latest_payload_at,
  la.action as latest_review_action,
  la.reviewer as latest_reviewer,
  la.notes as latest_review_notes,
  la.created_at as latest_review_at,
  case
    when la.action in ('approved_new_poll', 'approved_match') then 'reviewed'
    when la.action = 'rejected' then 'rejected'
    when la.action = 'needs_fix' then 'needs_fix'
    else 'pending'
  end as review_status,
  coalesce(cs.match_candidates, '[]'::jsonb) as match_candidates
from polls p
join elections e on e.id = p.election_id
join pollsters ps on ps.id = p.pollster_id
left join wiki_pages wp on wp.page_key = p.wiki_page
left join result_summary rs on rs.poll_id = p.id
left join anomaly_summary ans on ans.poll_id = p.id
left join latest_event le on le.poll_id = p.id
left join candidate_summary cs on cs.poll_id = p.id
left join latest_version lv on lv.poll_id = p.id
left join latest_action la on la.poll_id = p.id;

create or replace view admin_poll_review_queue as
select
  poll_id,
  election_key,
  territory_code,
  pollster_key,
  pollster_name,
  media,
  fieldwork_start,
  fieldwork_end,
  publication_date,
  sample_size,
  source_url,
  source_title,
  wiki_page,
  identity_status,
  identity_confidence,
  is_active,
  result_count,
  vote_share_sum,
  anomaly_count,
  error_count,
  warning_count,
  anomalies,
  latest_identity_event_type,
  latest_identity_event_reasons,
  latest_review_action,
  latest_reviewer,
  latest_review_at,
  review_status,
  case
    when review_status in ('pending', 'needs_fix') and error_count > 0 then 100
    when review_status in ('pending', 'needs_fix') and identity_status = 'manual_review' then 80
    when review_status in ('pending', 'needs_fix') and warning_count > 0 then 60
    else 10
  end as review_priority
from admin_poll_review_detail
where identity_status = 'manual_review'
   or anomaly_count > 0
   or review_status = 'needs_fix'
order by review_priority desc, updated_at desc, poll_id desc;

create or replace view api_poll_results_public as
select
  p.id as poll_id,
  e.election_key,
  e.election_type,
  e.territory_code,
  ps.pollster_key,
  ps.pollster_name,
  p.media,
  p.fieldwork_start,
  p.fieldwork_end,
  p.publication_date,
  p.sample_size,
  pr.party_key,
  pr.party_raw,
  coalesce(pa.party_name, pr.party_raw) as party_name,
  coalesce(pa.short_name, pr.party_raw) as short_name,
  pa.color_hex,
  pa.display_order,
  pr.vote_share,
  pr.seats_min,
  pr.seats_max
from polls p
join elections e on e.id = p.election_id
join pollsters ps on ps.id = p.pollster_id
join poll_results pr on pr.poll_id = p.id
left join parties pa on pa.party_key = pr.party_key
where p.is_active = true
  and p.identity_status <> 'manual_review';

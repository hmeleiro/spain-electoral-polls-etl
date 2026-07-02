run_sql_file <- function(con, path) {
  sql <- paste(readLines(path, warn = FALSE), collapse = "\n")
  DBI::dbExecute(con, sql)
}

get_election_id <- function(con, election_key) {
  out <- DBI::dbGetQuery(con, "select id from elections where election_key = $1", params = list(election_key))
  if (nrow(out) != 1) {
    stop("Election not found in database: ", election_key, call. = FALSE)
  }
  scalar_int(out$id)
}

revision_processed <- function(con, page_key, revision_id) {
  out <- DBI::dbGetQuery(
    con,
    "select 1 from wiki_page_revisions where page_key = $1 and revision_id = $2 and parse_status = 'success' limit 1",
    params = list(page_key, revision_id)
  )
  nrow(out) == 1
}

insert_scraper_run <- function(con, page_key, revision_id = NA_integer_) {
  out <- DBI::dbGetQuery(
    con,
    "insert into scraper_runs (started_at, status, page_key, revision_id)
     values (now(), 'running', $1, $2)
     returning id",
    params = list(page_key, revision_id)
  )
  scalar_int(out$id)
}

finish_scraper_run <- function(con, run_id, status, stats = list(), error_message = NA_character_) {
  DBI::dbExecute(
    con,
    "update scraper_runs
     set finished_at = now(),
         status = $2,
         rows_found = coalesce($3, rows_found),
         polls_inserted = coalesce($4, polls_inserted),
         polls_updated = coalesce($5, polls_updated),
         polls_unchanged = coalesce($6, polls_unchanged),
         polls_manual_review = coalesce($7, polls_manual_review),
         error_message = $8
     where id = $1",
    params = list(
      run_id,
      status,
      stats$rows_found %||% NA_integer_,
      stats$polls_inserted %||% NA_integer_,
      stats$polls_updated %||% NA_integer_,
      stats$polls_unchanged %||% NA_integer_,
      stats$polls_manual_review %||% NA_integer_,
      error_message
    )
  )
}

upsert_page_revision <- function(con, page_key, revision, raw_html, raw_wikitext, parse_status = "fetched", error_message = NA_character_) {
  content_sha256 <- digest::digest(raw_html %||% "", algo = "sha256", serialize = FALSE)
  DBI::dbExecute(
    con,
    "insert into wiki_page_revisions
       (page_key, revision_id, revision_timestamp, fetched_at, content_sha256, raw_html, raw_wikitext, parse_status, error_message)
     values
       ($1, $2, $3, now(), $4, $5, $6, $7, $8)
     on conflict (page_key, revision_id)
     do update set
       fetched_at = excluded.fetched_at,
       content_sha256 = excluded.content_sha256,
       raw_html = excluded.raw_html,
       raw_wikitext = excluded.raw_wikitext,
       parse_status = excluded.parse_status,
       error_message = excluded.error_message",
    params = list(
      page_key,
      revision$revision_id,
      revision$revision_timestamp,
      content_sha256,
      raw_html,
      raw_wikitext,
      parse_status,
      error_message
    )
  )
}

mark_page_revision_status <- function(con, page_key, revision_id, parse_status, error_message = NA_character_) {
  DBI::dbExecute(
    con,
    "update wiki_page_revisions set parse_status = $3, error_message = $4 where page_key = $1 and revision_id = $2",
    params = list(page_key, revision_id, parse_status, error_message)
  )
}

upsert_pollster <- function(con, pollster_name, pollster_key) {
  out <- DBI::dbGetQuery(
    con,
    "insert into pollsters (pollster_name, pollster_key)
     values ($1, $2)
     on conflict (pollster_key)
     do update set pollster_name = excluded.pollster_name
     returning id",
    params = list(pollster_name, pollster_key)
  )
  scalar_int(out$id)
}

fetch_existing_polls <- function(con, election_id, wiki_page) {
  rows <- DBI::dbGetQuery(
    con,
    "select
       p.id,
       p.poll_key_strict,
       p.poll_signature,
       e.election_key,
       ps.pollster_key,
       p.media,
       p.fieldwork_start,
       p.fieldwork_end,
       p.publication_date,
       p.sample_size,
       p.turnout,
       p.lead,
       p.source_url,
       p.source_title,
       p.source_reference_ids::text as source_reference_ids_json,
       p.source_metadata::text as source_metadata_json,
       p.row_hash,
       coalesce(
         jsonb_agg(
           jsonb_build_object(
             'party_key', pr.party_key,
             'party_raw', pr.party_raw,
             'vote_share', pr.vote_share,
             'seats_min', pr.seats_min,
             'seats_max', pr.seats_max,
             'raw_value', pr.raw_value
           )
         ) filter (where pr.id is not null),
         '[]'::jsonb
       )::text as results_json
     from polls p
     join elections e on e.id = p.election_id
     join pollsters ps on ps.id = p.pollster_id
     left join poll_results pr on pr.poll_id = p.id
     where p.election_id = $1 and p.wiki_page = $2 and p.is_active
     group by p.id, e.election_key, ps.pollster_key",
    params = list(election_id, wiki_page)
  )

  if (nrow(rows) == 0) {
    return(rows)
  }

  rows$id <- as.integer(rows$id)
  rows$media_key <- vapply(rows$media, normalize_media, character(1))
  rows$source_reference_ids <- lapply(rows$source_reference_ids_json, from_json_or_null)
  rows$source_metadata <- lapply(rows$source_metadata_json, from_json_or_null)
  rows$results <- lapply(rows$results_json, from_json_or_null)
  rows
}

latest_poll_payload <- function(con, poll_id) {
  out <- DBI::dbGetQuery(
    con,
    "select payload_json::text as payload_json
     from poll_versions
     where poll_id = $1
     order by valid_from desc, id desc
     limit 1",
    params = list(poll_id)
  )
  if (nrow(out) == 0) NULL else from_json_or_null(out$payload_json[[1]])
}

insert_poll_version <- function(con, poll_id, revision_id, row_hash, payload) {
  DBI::dbExecute(
    con,
    "insert into poll_versions (poll_id, wiki_revision_id, row_hash, payload_json, valid_from)
     values ($1, $2, $3, $4::jsonb, now())",
    params = list(poll_id, revision_id, row_hash, as_json(payload))
  )
}

insert_identity_event <- function(con, poll_id, revision_id, event_type, old_payload, new_payload, confidence, reasons) {
  DBI::dbExecute(
    con,
    "insert into poll_identity_events
       (poll_id, wiki_revision_id, event_type, old_payload, new_payload, confidence, reasons)
     values ($1, $2, $3, $4::jsonb, $5::jsonb, $6, $7::jsonb)",
    params = list(
      poll_id,
      revision_id,
      event_type,
      if (is.null(old_payload)) "null" else as_json(old_payload),
      if (is.null(new_payload)) "null" else as_json(new_payload),
      confidence,
      as_json(as.list(reasons))
    )
  )
}

insert_poll_results <- function(con, poll_id, results) {
  for (result in results) {
    DBI::dbExecute(
      con,
      "insert into poll_results
         (poll_id, party_key, party_raw, vote_share, seats_min, seats_max, raw_value)
       values ($1, $2, $3, $4, $5, $6, $7)
       on conflict (poll_id, party_key)
       do update set
         party_raw = excluded.party_raw,
         vote_share = excluded.vote_share,
         seats_min = excluded.seats_min,
         seats_max = excluded.seats_max,
         raw_value = excluded.raw_value",
      params = list(
        poll_id,
        result$party_key,
        result$party_raw,
        result$vote_share,
        result$seats_min,
        result$seats_max,
        result$raw_value
      )
    )
  }
}

insert_new_poll <- function(con, poll, election_id, pollster_id, identity_status, confidence) {
  out <- DBI::dbGetQuery(
    con,
    "insert into polls
       (poll_key_strict, poll_signature, election_id, pollster_id, media, fieldwork_start, fieldwork_end,
        publication_date, sample_size, turnout, lead, wiki_page, wiki_revision_id, source_url, source_title,
        source_reference_ids, source_metadata, row_hash,
        identity_status, identity_confidence, first_seen_at, last_seen_at, updated_at, is_active)
     values
       ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
        $16::jsonb, $17::jsonb, $18, $19, $20, now(), now(), now(), true)
     on conflict (poll_key_strict)
     do update set
       poll_signature = excluded.poll_signature,
       election_id = excluded.election_id,
       pollster_id = excluded.pollster_id,
       media = excluded.media,
       fieldwork_start = excluded.fieldwork_start,
       fieldwork_end = excluded.fieldwork_end,
       publication_date = excluded.publication_date,
       sample_size = excluded.sample_size,
       turnout = excluded.turnout,
       lead = excluded.lead,
       wiki_page = excluded.wiki_page,
       wiki_revision_id = excluded.wiki_revision_id,
       source_url = excluded.source_url,
       source_title = excluded.source_title,
       source_reference_ids = excluded.source_reference_ids,
       source_metadata = excluded.source_metadata,
       row_hash = excluded.row_hash,
       identity_status = excluded.identity_status,
       identity_confidence = excluded.identity_confidence,
       last_seen_at = now(),
       updated_at = now(),
       is_active = true
     returning id",
    params = list(
      poll$poll_key_strict,
      poll$poll_signature,
      election_id,
      pollster_id,
      poll$media,
      poll$fieldwork_start,
      poll$fieldwork_end,
      poll$publication_date,
      poll$sample_size,
      poll$turnout,
      poll$lead,
      poll$wiki_page,
      poll$wiki_revision_id,
      poll$source_url,
      poll$source_title,
      as_json(as.list(poll$source_reference_ids %||% character())),
      as_json(poll$source_metadata %||% list()),
      poll$row_hash,
      identity_status,
      confidence
    )
  )
  scalar_int(out$id)
}

update_existing_poll <- function(con, poll_id, poll, pollster_id, identity_status, confidence) {
  DBI::dbExecute(
    con,
    "update polls
     set poll_key_strict = $2,
         poll_signature = $3,
         pollster_id = $4,
         media = $5,
         fieldwork_start = $6,
         fieldwork_end = $7,
         publication_date = $8,
         sample_size = $9,
         turnout = $10,
         lead = $11,
         wiki_revision_id = $12,
         source_url = $13,
         source_title = $14,
         source_reference_ids = $15::jsonb,
         source_metadata = $16::jsonb,
         row_hash = $17,
         identity_status = $18,
         identity_confidence = $19,
         last_seen_at = now(),
         updated_at = now(),
         is_active = true
     where id = $1",
    params = list(
      poll_id,
      poll$poll_key_strict,
      poll$poll_signature,
      pollster_id,
      poll$media,
      poll$fieldwork_start,
      poll$fieldwork_end,
      poll$publication_date,
      poll$sample_size,
      poll$turnout,
      poll$lead,
      poll$wiki_revision_id,
      poll$source_url,
      poll$source_title,
      as_json(as.list(poll$source_reference_ids %||% character())),
      as_json(poll$source_metadata %||% list()),
      poll$row_hash,
      identity_status,
      confidence
    )
  )
}

change_event_types <- function(old_payload, new_payload) {
  events <- character()
  if (!identical(old_payload$fieldwork_start, new_payload$fieldwork_start) ||
      !identical(old_payload$fieldwork_end, new_payload$fieldwork_end)) {
    events <- c(events, "fieldwork_dates_corrected")
  }
  if (!identical(old_payload$sample_size, new_payload$sample_size)) {
    events <- c(events, "sample_size_corrected")
  }
  old_results <- as_json(old_payload$results %||% list())
  new_results <- as_json(new_payload$results %||% list())
  if (!identical(old_results, new_results)) {
    events <- c(events, "vote_share_corrected")
  }
  if (!identical(old_payload$pollster_key, new_payload$pollster_key)) {
    events <- c(events, "pollster_name_corrected")
  }
  events
}

deactivate_missing_polls <- function(con, election_id, page_key, seen_poll_ids, revision_id) {
  seen_poll_ids <- unique(as.integer(seen_poll_ids[!is.na(seen_poll_ids)]))
  if (length(seen_poll_ids) == 0) {
    return(0L)
  }

  missing_sql <- glue::glue_sql(
    "select id
     from polls
     where election_id = {election_id}
       and wiki_page = {page_key}
       and is_active
       and id not in ({seen_poll_ids*})",
    .con = con
  )
  missing <- DBI::dbGetQuery(con, missing_sql)
  if (nrow(missing) == 0) {
    return(0L)
  }

  missing$id <- as.integer(missing$id)
  for (poll_id in missing$id) {
    old_payload <- latest_poll_payload(con, poll_id) %||% list(poll_id = poll_id)
    new_payload <- list(
      poll_id = poll_id,
      page_key = page_key,
      wiki_revision_id = revision_id,
      is_active = FALSE
    )

    DBI::dbExecute(
      con,
      "update polls
       set is_active = false,
           wiki_revision_id = $2,
           updated_at = now()
       where id = $1",
      params = list(poll_id, revision_id)
    )
    insert_identity_event(
      con,
      poll_id,
      revision_id,
      "poll_missing_from_revision",
      old_payload,
      new_payload,
      1,
      c("not_seen_in_current_revision")
    )
  }

  as.integer(nrow(missing))
}

upsert_normalized_polls <- function(con, polls, page_key, revision_id) {
  election_id <- get_election_id(con, polls[[1]]$election_key)
  stats <- list(
    rows_found = length(polls),
    polls_inserted = 0L,
    polls_updated = 0L,
    polls_unchanged = 0L,
    polls_manual_review = 0L,
    polls_deactivated = 0L
  )
  seen_poll_ids <- integer()

  for (poll in polls) {
    pollster_id <- upsert_pollster(con, poll$pollster_raw, poll$pollster_key)
    existing <- fetch_existing_polls(con, election_id, page_key)
    match <- match_existing_poll(poll, existing)
    payload <- stable_poll_payload(poll)

    if (match$match_type %in% c("new_poll", "manual_review") && is.na(match$poll_id)) {
      status <- match$match_type
      poll_id <- insert_new_poll(con, poll, election_id, pollster_id, status, match$confidence)
      seen_poll_ids <- c(seen_poll_ids, poll_id)
      insert_poll_results(con, poll_id, poll$results)
      insert_poll_version(con, poll_id, revision_id, poll$row_hash, payload)
      insert_identity_event(con, poll_id, revision_id, status, NULL, payload, match$confidence, match$reasons)
      if (status == "manual_review") {
        stats$polls_manual_review <- stats$polls_manual_review + 1L
      } else {
        stats$polls_inserted <- stats$polls_inserted + 1L
      }
      next
    }

    existing_row <- existing[existing$id == match$poll_id, , drop = FALSE]
    seen_poll_ids <- c(seen_poll_ids, match$poll_id)
    old_payload <- latest_poll_payload(con, match$poll_id)
    if (is.null(old_payload)) {
      old_payload <- row_to_poll_list(existing_row)
    }

    if (nrow(existing_row) == 1 && identical(existing_row$row_hash[[1]], poll$row_hash)) {
      update_existing_poll(con, match$poll_id, poll, pollster_id, match$match_type, match$confidence)
      event_type <- if (match$match_type == "exact") "exact_match" else "probable_match"
      insert_identity_event(con, match$poll_id, revision_id, event_type, old_payload, payload, match$confidence, match$reasons)
      stats$polls_unchanged <- stats$polls_unchanged + 1L
      next
    }

    update_existing_poll(con, match$poll_id, poll, pollster_id, match$match_type, match$confidence)
    insert_poll_results(con, match$poll_id, poll$results)
    insert_poll_version(con, match$poll_id, revision_id, poll$row_hash, payload)
    event_type <- if (match$match_type == "exact") "exact_match" else "probable_match"
    insert_identity_event(con, match$poll_id, revision_id, event_type, old_payload, payload, match$confidence, match$reasons)
    for (event_type in change_event_types(old_payload, payload)) {
      insert_identity_event(con, match$poll_id, revision_id, event_type, old_payload, payload, match$confidence, match$reasons)
    }
    stats$polls_updated <- stats$polls_updated + 1L
  }

  stats$polls_deactivated <- deactivate_missing_polls(con, election_id, page_key, seen_poll_ids, revision_id)
  stats
}

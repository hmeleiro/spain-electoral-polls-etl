manual_review_actions <- function() {
  c("approved_new_poll", "approved_match", "rejected", "needs_fix", "comment")
}

review_decision_to_identity_status <- function(action) {
  action <- match.arg(action, manual_review_actions())
  switch(
    action,
    approved_new_poll = "new_poll",
    approved_match = "probable_match",
    rejected = "manual_review",
    needs_fix = "manual_review",
    comment = NA_character_
  )
}

validate_pagination <- function(limit, offset) {
  limit <- as.integer(limit)
  offset <- as.integer(offset)
  if (is.na(limit) || limit < 1L || limit > 1000L) {
    stop("limit must be between 1 and 1000.", call. = FALSE)
  }
  if (is.na(offset) || offset < 0L) {
    stop("offset must be 0 or greater.", call. = FALSE)
  }
  list(limit = limit, offset = offset)
}

add_param_filter <- function(sql, params, column, value) {
  if (is_blank(value)) {
    return(list(sql = sql, params = params))
  }
  params <- c(params, list(value))
  placeholder <- paste0("$", length(params))
  list(
    sql = paste(sql, "and", column, "=", placeholder),
    params = params
  )
}

list_manual_review_polls <- function(
    con,
    election_key = NA_character_,
    page_key = NA_character_,
    review_status = NA_character_,
    limit = 100L,
    offset = 0L) {
  pagination <- validate_pagination(limit, offset)
  sql <- "select * from admin_poll_review_queue where 1 = 1"
  params <- list()

  filtered <- add_param_filter(sql, params, "election_key", election_key)
  sql <- filtered$sql
  params <- filtered$params

  filtered <- add_param_filter(sql, params, "wiki_page", page_key)
  sql <- filtered$sql
  params <- filtered$params

  filtered <- add_param_filter(sql, params, "review_status", review_status)
  sql <- filtered$sql
  params <- filtered$params

  params <- c(params, list(pagination$limit, pagination$offset))
  sql <- paste(
    sql,
    "order by review_priority desc, fieldwork_end desc nulls last, publication_date desc nulls last, poll_id desc",
    paste0("limit $", length(params) - 1L),
    paste0("offset $", length(params))
  )
  DBI::dbGetQuery(con, sql, params = params)
}

get_manual_review_poll <- function(con, poll_id) {
  poll_id <- as.integer(poll_id)
  if (is.na(poll_id)) {
    stop("poll_id must be an integer.", call. = FALSE)
  }

  detail <- DBI::dbGetQuery(
    con,
    "select * from admin_poll_review_detail where poll_id = $1",
    params = list(poll_id)
  )
  if (nrow(detail) != 1) {
    stop("Manual review poll not found: ", poll_id, call. = FALSE)
  }

  results <- DBI::dbGetQuery(
    con,
    "select *
     from admin_poll_review_results
     where poll_id = $1
     order by display_order nulls last, party_key",
    params = list(poll_id)
  )
  anomalies <- DBI::dbGetQuery(
    con,
    "select *
     from admin_poll_review_anomalies
     where poll_id = $1
     order by case severity when 'error' then 1 when 'warning' then 2 else 3 end, anomaly_code",
    params = list(poll_id)
  )
  actions <- DBI::dbGetQuery(
    con,
    "select *
     from poll_review_actions
     where poll_id = $1
     order by created_at desc, id desc",
    params = list(poll_id)
  )

  list(
    detail = detail,
    results = results,
    anomalies = anomalies,
    actions = actions
  )
}

record_poll_review_decision <- function(
    con,
    poll_id,
    action,
    reviewer = NA_character_,
    notes = NA_character_,
    corrected_payload = list()) {
  poll_id <- as.integer(poll_id)
  if (is.na(poll_id)) {
    stop("poll_id must be an integer.", call. = FALSE)
  }
  action <- match.arg(action, manual_review_actions())
  next_identity_status <- review_decision_to_identity_status(action)
  corrected_payload <- corrected_payload %||% list()

  DBI::dbWithTransaction(con, {
    current <- DBI::dbGetQuery(
      con,
      "select id, identity_status, is_active
       from polls
       where id = $1
       for update",
      params = list(poll_id)
    )
    if (nrow(current) != 1) {
      stop("Poll not found: ", poll_id, call. = FALSE)
    }

    previous_identity_status <- current$identity_status[[1]]
    stored_identity_status <- if (is.na(next_identity_status)) {
      previous_identity_status
    } else {
      next_identity_status
    }

    action_row <- DBI::dbGetQuery(
      con,
      "insert into poll_review_actions
         (poll_id, action, previous_identity_status, new_identity_status, reviewer, notes, corrected_payload)
       values
         ($1, $2, $3, $4, $5, $6, $7::jsonb)
       returning id",
      params = list(
        poll_id,
        action,
        previous_identity_status,
        stored_identity_status,
        reviewer,
        notes,
        as_json(corrected_payload)
      )
    )

    if (action %in% c("approved_new_poll", "approved_match")) {
      DBI::dbExecute(
        con,
        "update polls
         set identity_status = $2,
             is_active = true,
             updated_at = now()
         where id = $1",
        params = list(poll_id, stored_identity_status)
      )
    } else if (identical(action, "rejected")) {
      DBI::dbExecute(
        con,
        "update polls
         set identity_status = 'manual_review',
             is_active = false,
             updated_at = now()
         where id = $1",
        params = list(poll_id)
      )
    } else if (identical(action, "needs_fix")) {
      DBI::dbExecute(
        con,
        "update polls
         set identity_status = 'manual_review',
             updated_at = now()
         where id = $1",
        params = list(poll_id)
      )
    }

    DBI::dbExecute(
      con,
      "insert into poll_identity_events
         (poll_id, wiki_revision_id, event_type, old_payload, new_payload, confidence, reasons)
       select
         p.id,
         p.wiki_revision_id,
         $2,
         jsonb_build_object('identity_status', $3, 'is_active', $4),
         jsonb_build_object('identity_status', p.identity_status, 'is_active', p.is_active, 'review_action_id', $5::bigint),
         p.identity_confidence,
         jsonb_build_array($6)
       from polls p
       where p.id = $1",
      params = list(
        poll_id,
        paste0("manual_review_", action),
        previous_identity_status,
        current$is_active[[1]],
        scalar_int(action_row$id),
        "admin_review_decision"
      )
    )

    scalar_int(action_row$id)
  })
}

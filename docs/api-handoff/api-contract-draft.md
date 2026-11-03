# API Contract Draft

Valores por defecto recomendados para listados:

- `limit = 100`
- `offset = 0`
- `max_limit = 1000`

Todos los endpoints de listado deben devolver:

```json
{
  "items": [],
  "limit": 100,
  "offset": 0,
  "total": 0
}
```

## GET /health

### Proposito
Comprobar que la API responde y, opcionalmente, que la base de datos esta accesible.
### Query params
Ninguno.
### Respuesta JSON esperada
```json
{ "status": "ok", "database": "ok" }
```
### Tablas consultadas
Opcionalmente `select 1`.
### Reglas de negocio aplicables
No exponer credenciales ni detalles de conexion.

## GET /api/v1/elections

### Proposito
Listar elecciones disponibles.
### Query params
`territory_code`, `election_type`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    {
      "id": 1,
      "election_key": "congreso_espana_2026",
      "election_type": "general",
      "territory_code": "ES",
      "election_name": "Next Spanish general election",
      "election_date": null
    }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
`elections`.
### Reglas de negocio aplicables
Endpoint publico.

## GET /api/v1/pollsters

### Proposito
Listar encuestadoras.
### Query params
`election_key`, `active_only=true`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "id": 12, "pollster_key": "40db", "pollster_name": "40dB", "poll_count": 18 }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
`pollsters`, opcionalmente `polls`, `elections`.
### Reglas de negocio aplicables
Si `active_only=true`, contar solo `polls.is_active = true` y no `manual_review`.

## GET /api/v1/parties

### Proposito
Listar el catalogo canonico de partidos.
### Query params
`territory_code`, `active_only=true`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "party_key": "pp", "party_name": "Partido Popular", "short_name": "PP", "territory_code": "ES", "color_hex": "#1d84ce", "display_order": 20 },
    { "party_key": "psoe", "party_name": "Partido Socialista Obrero Espanol", "short_name": "PSOE", "territory_code": "ES", "color_hex": "#e30613", "display_order": 10 }
  ],
  "limit": 100,
  "offset": 0,
  "total": 2
}
```
### Tablas consultadas
`parties`.
### Reglas de negocio aplicables
Ordenar por `display_order`, `party_key`. Si `active_only=true`, aplicar `parties.is_active = true`.

## GET /api/v1/polls

### Proposito
Listar encuestas paginadas.
### Query params
`election_key`, `territory_code`, `pollster_key`, `media`, `fieldwork_start_from`, `fieldwork_end_to`, `publication_date_from`, `publication_date_to`, `identity_status`, `include_manual_review=false`, `include_inactive=false`, `limit`, `offset`, `sort`.
### Respuesta JSON esperada
```json
{
  "items": [
    {
      "id": 101,
      "election_key": "congreso_espana_2026",
      "pollster_key": "40db",
      "pollster_name": "40dB",
      "media": "Prisa",
      "fieldwork_start": "2026-05-28",
      "fieldwork_end": "2026-06-01",
      "publication_date": "2026-06-02",
      "sample_size": 2000,
      "turnout": null,
      "lead": 4.5,
      "source_url": "https://example.com/poll",
      "source_title": "40dB poll headline",
      "identity_status": "exact",
      "first_seen_at": "2026-07-01T10:00:00Z",
      "is_active": true
    }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
Preferentemente `api_polls_public`; usar tablas base solo si se solicitan `include_manual_review` o `include_inactive`.
### Reglas de negocio aplicables
Excluir por defecto `is_active = false` y `manual_review`.

## GET /api/v1/polls/{poll_id}

### Proposito
Ficha completa de una encuesta con resultados.
### Query params
`include_manual_review=false`, `include_inactive=false`.
### Respuesta JSON esperada
```json
{
  "id": 101,
  "election_key": "congreso_espana_2026",
  "pollster_key": "40db",
  "pollster_name": "40dB",
  "media": "Prisa",
  "fieldwork_start": "2026-05-28",
  "fieldwork_end": "2026-06-01",
  "publication_date": "2026-06-02",
  "sample_size": 2000,
  "turnout": null,
  "lead": 4.5,
  "source_url": "https://example.com/poll",
  "source_title": "40dB poll headline",
  "identity_status": "exact",
  "is_active": true,
  "results": [
    { "party_key": "pp", "party_raw": "PP", "vote_share": 32.4, "seats_min": null, "seats_max": null },
    { "party_key": "psoe", "party_raw": "PSOE", "vote_share": 27.9, "seats_min": null, "seats_max": null }
  ]
}
```
### Tablas consultadas
`polls`, `poll_results`, `pollsters`, `elections`.
### Reglas de negocio aplicables
No incluir `row_hash`, `poll_signature`, `raw_value`, `source_reference_ids` ni `source_metadata` por defecto.

## GET /api/v1/polls/{poll_id}/results

### Proposito
Resultados long de una encuesta.
### Query params
`include_raw=false`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "poll_id": 101, "party_key": "pp", "party_raw": "PP", "vote_share": 32.4, "seats_min": null, "seats_max": null }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
`poll_results`, `polls`.
### Reglas de negocio aplicables
`raw_value` solo si `include_raw=true` y el endpoint se considera debug/admin.

## GET /api/v1/results

### Proposito
Consultar resultados long con filtros.
### Query params
`election_key`, `pollster_key`, `media`, `party_key`, `fieldwork_start_from`, `fieldwork_end_to`, `include_manual_review=false`, `include_inactive=false`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    {
      "poll_id": 101,
      "date": "2026-06-01",
      "party_key": "pp",
      "party_raw": "PP",
      "vote_share": 32.4,
      "pollster_key": "40db",
      "pollster_name": "40dB",
      "media": "Prisa",
      "sample_size": 2000
    }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
Preferentemente `api_poll_results_public`; usar tablas base solo si se solicitan `include_manual_review` o `include_inactive`.
### Reglas de negocio aplicables
Formato long; filtrar en SQL.

## GET /api/v1/timeseries

### Proposito
Serie temporal optimizada para dashboard.
### Query params
`election_key`, `party_key`, `pollster_key`, `media`, `date_field=auto|fieldwork_end|publication_date`, `date_from`, `date_to`, `include_manual_review=false`, `include_inactive=false`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    {
      "date": "2026-06-01",
      "poll_id": 101,
      "party_key": "pp",
      "vote_share": 32.4,
      "pollster_key": "40db",
      "media": "Prisa"
    }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
Preferentemente `api_poll_results_public`; usar tablas base solo si se solicitan `include_manual_review` o `include_inactive`.
### Reglas de negocio aplicables
`date_field=auto` usa `coalesce(fieldwork_end, publication_date)`. Para dashboards orientados a publicacion, el cliente debe pedir explicitamente `date_field=publication_date`.

## GET /api/v1/admin/polls/{poll_id}/source

### Proposito
Auditar la fuente Wikipedia usada para fecha de publicacion y URL externa.
### Query params
Ninguno.
### Respuesta JSON esperada
```json
{
  "poll_id": 101,
  "source_url": "https://example.com/poll",
  "source_title": "40dB poll headline",
  "source_reference_ids": ["cite_note-1"],
  "source_metadata": {
    "cite_note-1": {
      "reference_id": "cite_note-1",
      "url": "https://example.com/poll",
      "title": "40dB poll headline",
      "publisher": "Prisa",
      "publication_date": "2026-06-02",
      "publication_date_raw": "2026-06-02",
      "reference_text": "^ 40dB poll headline. Prisa. 2 June 2026."
    }
  }
}
```
### Tablas consultadas
`polls`.
### Reglas de negocio aplicables
Admin/debug; no exponer `source_metadata` completo en endpoints publicos.

## GET /api/v1/admin/scraper-runs

### Proposito
Monitorizar ejecuciones del scraper.
### Query params
`page_key`, `status`, `started_from`, `started_to`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "id": 55, "started_at": "2026-07-01T08:00:00Z", "finished_at": "2026-07-01T08:01:12Z", "status": "success", "page_key": "next_spanish_general_election", "revision_id": 123456789, "rows_found": 30, "polls_inserted": 2, "polls_updated": 1, "polls_unchanged": 27, "polls_manual_review": 0 }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
`scraper_runs`.
### Reglas de negocio aplicables
Admin protegido; cuidado con `error_message`.

## GET /api/v1/admin/manual-review

### Proposito
Listar la bandeja visual de encuestas que requieren revision manual o presentan anomalias.
### Query params
`election_key`, `page_key`, `review_status=pending|needs_fix|reviewed|rejected`, `limit`, `offset`.
### Validacion
`limit` entre `1` y `1000`; `offset >= 0`; `review_status` solo admite `pending`, `needs_fix`, `reviewed`, `rejected`.
### Respuesta JSON esperada
```json
{
  "items": [
    {
      "poll_id": 202,
      "election_key": "congreso_espana_2026",
      "territory_code": "ES",
      "pollster_name": "Example Pollster",
      "media": "Example Media",
      "fieldwork_start": "2026-06-01",
      "fieldwork_end": "2026-06-05",
      "publication_date": "2026-06-06",
      "sample_size": 1200,
      "source_url": "https://example.com/poll",
      "identity_status": "manual_review",
      "identity_confidence": 0.76,
      "result_count": 8,
      "vote_share_sum": 92.4,
      "anomaly_count": 2,
      "error_count": 0,
      "warning_count": 2,
      "review_status": "pending",
      "review_priority": 80,
      "anomalies": [
        { "severity": "warning", "code": "manual_review_status", "message": "La encuesta esta marcada para revision manual." }
      ]
    }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
Preferentemente `admin_poll_review_queue`.
### Reglas de negocio aplicables
Admin protegido. Ordenar por `review_priority desc` y fecha reciente. Esta respuesta esta pensada para una bandeja visual, no para API publica.
### Notas de implementacion
Calcular `total` con los mismos filtros antes de aplicar `limit/offset`. El parametro `page_key` filtra la columna `wiki_page`.

## GET /api/v1/admin/manual-review/{poll_id}

### Proposito
Obtener la ficha completa de revision visual de una encuesta.
### Query params
Ninguno.
### Respuesta JSON esperada
```json
{
  "poll_id": 202,
  "election_key": "congreso_espana_2026",
  "pollster_name": "Example Pollster",
  "media": "Example Media",
  "fieldwork_start": "2026-06-01",
  "fieldwork_end": "2026-06-05",
  "publication_date": "2026-06-06",
  "sample_size": 1200,
  "source_url": "https://example.com/poll",
  "source_title": "Example poll headline",
  "identity_status": "manual_review",
  "identity_confidence": 0.76,
  "vote_share_sum": 92.4,
  "anomalies": [
    { "severity": "warning", "code": "low_identity_confidence", "message": "La confianza del matching esta por debajo de 0.85." }
  ],
  "results": [
    {
      "party_key": "pp",
      "short_name": "PP",
      "color_hex": "#1d84ce",
      "vote_share": 32.4,
      "recent_average_vote_share": 31.1,
      "delta_from_recent_average": 1.3,
      "is_unknown_party": false,
      "raw_value": "32.4"
    }
  ],
  "match_candidates": [
    {
      "candidate_poll_id": 184,
      "rank": 1,
      "confidence": 0.82,
      "reasons": ["same_election", "same_pollster", "same_media", "identical_vote_results"],
      "pollster_name": "40dB",
      "media": "El Pais",
      "fieldwork_start": "2026-05-28",
      "fieldwork_end": "2026-06-02",
      "publication_date": "2026-06-03",
      "sample_size": 1200,
      "source_url": "https://example.com/previous",
      "identity_status": "probable_match",
      "vote_share_sum": 92.1,
      "results": [
        { "party_key": "pp", "party_raw": "PP", "vote_share": 32.8 },
        { "party_key": "psoe", "party_raw": "PSOE", "vote_share": 28.9 }
      ]
    }
  ],
  "latest_identity_event_reasons": ["ambiguous_or_low_confidence", "same_pollster"]
}
```
### Tablas consultadas
Preferentemente `admin_poll_review_detail`.
### Reglas de negocio aplicables
Admin protegido. Puede exponer `source_metadata`, `latest_payload_json`, `raw_value` y razones de matching porque es una pantalla operativa.
### Notas de implementacion
Devolver `404` si `poll_id` no existe. Los campos JSONB como `anomalies`, `results`, `match_candidates`, `source_metadata`, `source_reference_ids`, `latest_identity_event_reasons` y `latest_payload_json` deben salir como JSON nativo, no como strings.

## POST /api/v1/admin/manual-review/{poll_id}/actions

### Proposito
Registrar una decision de revision y actualizar la visibilidad de la encuesta cuando proceda.
### Body JSON esperado
```json
{
  "action": "approved_new_poll",
  "reviewer": "admin@example.com",
  "notes": "La fila coincide con la fuente.",
  "corrected_payload": {}
}
```
### Validacion
`action` debe ser uno de `approved_new_poll`, `approved_match`, `rejected`, `needs_fix`, `comment`. `corrected_payload` debe tratarse como objeto JSON; si falta, usar `{}`.
### Respuesta JSON esperada
```json
{
  "poll_id": 202,
  "review_action_id": 77,
  "action": "approved_new_poll"
}
```
### Tablas consultadas/modificadas
`poll_review_actions`, `polls`, `poll_identity_events`.
### Reglas de negocio aplicables
Acciones validas: `approved_new_poll`, `approved_match`, `rejected`, `needs_fix`, `comment`. `approved_new_poll` cambia `identity_status` a `new_poll`; `approved_match` lo cambia a `probable_match`; `rejected` mantiene `manual_review` y pone `is_active=false`; `needs_fix` mantiene `manual_review`.
### Notas de implementacion
Debe ejecutarse en transaccion. Bloquear `polls` con `for update`, insertar `poll_review_actions`, actualizar `polls` si procede e insertar `poll_identity_events` con `event_type = 'manual_review_' || action`. Devolver `404` si `poll_id` no existe.

## GET /api/v1/admin/poll-versions/{poll_id}

### Proposito
Historico de versiones de una encuesta.
### Query params
`limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "id": 301, "poll_id": 101, "wiki_revision_id": 123456789, "valid_from": "2026-07-01T08:00:00Z", "payload_json": { "pollster_key": "40db", "sample_size": 2000 } }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
`poll_versions`.
### Reglas de negocio aplicables
Admin protegido.

## GET /api/v1/admin/poll-identity-events/{poll_id}

### Proposito
Auditar matching y cambios de identidad.
### Query params
`limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "id": 401, "poll_id": 101, "wiki_revision_id": 123456789, "event_type": "exact_match", "confidence": 1.0, "created_at": "2026-07-01T08:00:00Z" }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
`poll_identity_events`.
### Reglas de negocio aplicables
No publicar `old_payload`, `new_payload` ni `reasons` fuera de admin/debug.

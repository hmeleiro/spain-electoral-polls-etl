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
      "election_key": "congreso_espana_2027",
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
Listar partidos disponibles derivados de resultados.
### Query params
`election_key`, `active_only=true`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "party_key": "pp", "party_raw": "PP", "poll_count": 42 },
    { "party_key": "psoe", "party_raw": "PSOE", "poll_count": 42 }
  ],
  "limit": 100,
  "offset": 0,
  "total": 2
}
```
### Tablas consultadas
`poll_results`, `polls`, `elections`.
### Reglas de negocio aplicables
No hay tabla `parties`; deduplicar por `party_key`.

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
      "election_key": "congreso_espana_2027",
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
`polls`, `pollsters`, `elections`.
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
  "election_key": "congreso_espana_2027",
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
`poll_results`, `polls`, `pollsters`, `elections`.
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
`polls`, `poll_results`, `pollsters`, `elections`.
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
Listar encuestas que requieren revision manual.
### Query params
`election_key`, `page_key`, `limit`, `offset`.
### Respuesta JSON esperada
```json
{
  "items": [
    { "id": 202, "election_key": "congreso_espana_2027", "pollster_name": "Example Pollster", "identity_status": "manual_review", "identity_confidence": 0.76, "is_active": true }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```
### Tablas consultadas
`polls`, `pollsters`, `elections`.
### Reglas de negocio aplicables
Admin/debug; puede exponer `identity_confidence`, no `row_hash`.

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

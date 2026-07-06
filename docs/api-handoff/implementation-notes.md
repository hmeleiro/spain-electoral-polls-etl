# Implementation Notes

## Tablas para la API publica

Consultar normalmente:

- `api_polls_public`
- `api_poll_results_public`
- `elections`
- `pollsters`
- `parties`
- `polls`
- `poll_results`

## Tablas reservadas para endpoints administrativos

- `wiki_pages`
- `wiki_page_revisions`
- `poll_versions`
- `poll_identity_events`
- `scraper_runs`
- `poll_review_actions`

## Vistas para revision visual admin

Consultar normalmente:

- `admin_poll_review_queue`
- `admin_poll_review_detail`
- `admin_poll_review_results`
- `admin_poll_review_anomalies`
- `admin_poll_review_match_candidates`

## Endpoints requeridos por el Admin UI

El frontend `admin-ui/` consume exactamente:

- `GET /api/v1/admin/manual-review`
- `GET /api/v1/admin/manual-review/{poll_id}`
- `POST /api/v1/admin/manual-review/{poll_id}/actions`

El cliente esta en `admin-ui/src/api.ts` y espera JSON con nombres `snake_case`. No convertir a `camelCase`.

En desarrollo, si frontend y API corren en puertos distintos, habilitar CORS para:

```text
http://127.0.0.1:5173
```

Tambien puede usarse `VITE_API_BASE_URL` en `admin-ui/.env` para apuntar al host real de la API.

## Campos que no debe exponer la API publica

- `polls.row_hash`
- `polls.poll_signature`
- `polls.source_metadata`
- `poll_versions.row_hash`
- `poll_versions.payload_json`
- `poll_identity_events.old_payload`
- `poll_identity_events.new_payload`
- `poll_identity_events.reasons`
- `wiki_page_revisions.raw_html`
- `wiki_page_revisions.raw_wikitext`

`poll_key_strict` puede ayudar internamente, pero no debe ser el identificador publico principal.

## Joins frecuentes

Listado de encuestas:

```sql
from api_polls_public
```

Resultados long:

```sql
from api_poll_results_public
```

Ficha completa:

```sql
from polls p
join elections e on e.id = p.election_id
join pollsters ps on ps.id = p.pollster_id
left join poll_results pr on pr.poll_id = p.id
left join parties pa on pa.party_key = pr.party_key
where p.id = $1
```

## Indices utiles para rendimiento

Ya existen indices para revisiones, filtros publicos, pollster, media, party, fecha de publicacion, metadata de fuente, versiones, eventos y scraper runs. Para endpoints de series, el indice mas relevante es:

```sql
idx_polls_public_filters
```

Si el volumen crece, evaluar indices compuestos adicionales sobre `poll_results(party_key, poll_id)` y sobre expresiones de fecha si se usan mucho.

## Filtros que deben aplicarse en SQL

- `election_key`
- `territory_code`
- `pollster_key`
- `media`
- `party_key`
- `fieldwork_start`
- `fieldwork_end`
- `publication_date`
- `identity_status`
- `is_active`
- `limit` y `offset`

## Como tratar `manual_review`

Default publico:

```sql
p.identity_status <> 'manual_review'
```

Solo incluirlo si el cliente envia `include_manual_review=true` o si se consulta un endpoint administrativo.

Para pantallas admin, preferir `admin_poll_review_queue` como bandeja y `admin_poll_review_detail` como ficha. Las decisiones deben registrarse en `poll_review_actions` y reflejarse en `poll_identity_events` para mantener auditoria tecnica y operativa.

`admin_poll_review_detail` incluye `match_candidates`, un array JSON con las encuestas existentes que el ETL considero parecidas durante el matching. La API debe devolverlo como array JSON nativo para que el Admin UI pueda cotejar si la encuesta en revision es nueva o corresponde a una encuesta ya registrada.

## Como implementar acciones de revision

Las acciones validas son:

- `approved_new_poll`
- `approved_match`
- `rejected`
- `needs_fix`
- `comment`

Mapeo de accion a efecto:

| Accion | `polls.identity_status` | `polls.is_active` |
|---|---|---|
| `approved_new_poll` | `new_poll` | `true` |
| `approved_match` | `probable_match` | `true` |
| `rejected` | `manual_review` | `false` |
| `needs_fix` | `manual_review` | sin cambio |
| `comment` | sin cambio | sin cambio |

Implementar `POST /api/v1/admin/manual-review/{poll_id}/actions` siempre dentro de una transaccion:

1. Bloquear `polls` con `for update`.
2. Insertar `poll_review_actions`.
3. Actualizar `polls` si la accion lo requiere.
4. Insertar `poll_identity_events` con `event_type = 'manual_review_' || action`.

La respuesta minima esperada por el Admin UI es:

```json
{ "poll_id": 202, "review_action_id": 77, "action": "approved_new_poll" }
```

Si `poll_id` no existe, devolver `404`. Si `action` no es valida, devolver error de validacion.

## Como tratar `is_active`

Default publico:

```sql
p.is_active = true
```

Solo incluir inactivas con `include_inactive=true` o en endpoints administrativos. Una encuesta inactiva no se elimina: representa una fila que desaparecio de la revision actual o dejo de pasar filtros del scraper.

## Como construir la fecha de serie temporal

- `date_field=fieldwork_end`: usar `p.fieldwork_end`.
- `date_field=publication_date`: usar `p.publication_date`.
- `date_field=auto`: usar `coalesce(p.fieldwork_end, p.publication_date)`.

`publication_date` se extrae de las referencias de Wikipedia cuando existe. No asumir que coincide con `fieldwork_end`; en encuestas publicadas despues de terminar el campo puede ser posterior.

## Como exponer fuente/publicacion

En endpoints publicos, devolver como maximo:

- `publication_date`
- `source_url`
- `source_title`

Reservar para admin/debug:

- `source_reference_ids`
- `source_metadata`

`source_metadata` es JSONB con metadatos de una o varias referencias (`reference_id`, `url`, `title`, `publisher`, `publication_date`, `publication_date_raw`, `reference_text`). Puede contener texto largo de Wikipedia.

## Endpoints que podrian necesitar optimizacion futura

- `/api/v1/timeseries` con muchos partidos y rangos largos.
- `/api/v1/results` si se usa como descarga masiva.
- Endpoints admin de `poll_versions` si `payload_json` crece.

## Decisiones abiertas

- Persistir `media_key`.
- Autenticacion y autorizacion para `/admin`.
- Politica exacta de exposicion de `identity_status`.
- Workflow de resolucion de `manual_review`.

## Supuestos que no debe hacer el agente de la API

- No asumir que `publication_date` coincide con `fieldwork_end`.
- No asumir que solo existe una pagina/election: ya hay fuentes para `next_spanish_general_election` y `spanish_general_election_2023`.
- No asumir que todos los `poll_results.party_key` existen en `parties`; el join debe ser `left join`.
- No asumir que existe una columna `media_key`.
- No asumir que `wiki_revision_id` tiene FK a `wiki_page_revisions`.
- No asumir que `manual_review` es apto para dashboard publico.
- No asumir que `raw_value` es necesario para usuarios finales.
- No modificar datos desde la API v1.

## Checklist para el agente de la API

- Revisar `sql/001_schema.sql` y `sql/002_indexes.sql`.
- Revisar `admin-ui/src/api.ts` y `admin-ui/src/types.ts` antes de implementar endpoints admin.
- Implementar paginacion con `limit`, `offset`, `total`.
- Aplicar por defecto `is_active = true`.
- Excluir por defecto `identity_status = 'manual_review'`.
- Usar `polls.id` como `poll_id` publico en v1.
- Devolver fechas en ISO 8601.
- Devolver `vote_share`, `lead` y `turnout` como numeros.
- Mantener resultados en formato long para `/results` y `/timeseries`.
- No exponer hashes, firmas ni payloads internos en endpoints publicos.
- Filtrar en SQL, no en memoria.
- Proteger o posponer endpoints `/admin`.
- Para endpoints del Admin UI, usar `admin_poll_review_queue` y `admin_poll_review_detail`.
- Para decisiones admin, registrar siempre `poll_review_actions` y `poll_identity_events`.

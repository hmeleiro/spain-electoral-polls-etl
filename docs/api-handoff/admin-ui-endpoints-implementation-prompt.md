# Prompt para implementar endpoints del Admin UI

Copia este prompt para el agente de IA que vaya a actualizar la API.

```text
Necesito implementar los endpoints que consume el frontend `admin-ui/` del repo `spain-electoral-polls`.

Contexto:

- La API debe exponer endpoints administrativos para revision manual de encuestas.
- El frontend esta en `admin-ui/` y su cliente HTTP esta en `admin-ui/src/api.ts`.
- El contrato esta en `docs/api-handoff/api-contract-draft.md`.
- Las notas de implementacion estan en `docs/api-handoff/implementation-notes.md`.
- El esquema base esta en `sql/001_schema.sql` y los indices/vistas estan en `sql/002_indexes.sql`.
- Las vistas principales que debes usar son:
  - `admin_poll_review_queue`
  - `admin_poll_review_detail`
  - `admin_poll_review_results`
  - `admin_poll_review_anomalies`
  - `admin_poll_review_match_candidates`
- La tabla de acciones es `poll_review_actions`.
- Las decisiones tambien deben dejar evento en `poll_identity_events`.

Endpoints obligatorios:

1. `GET /api/v1/admin/manual-review`

Query params:

- `election_key` opcional
- `page_key` opcional; filtra `wiki_page`
- `review_status` opcional; valores: `pending`, `needs_fix`, `reviewed`, `rejected`
- `limit` default `100`, max `1000`
- `offset` default `0`

Respuesta:

```json
{
  "items": [],
  "limit": 100,
  "offset": 0,
  "total": 0
}
```

Cada item debe salir de `admin_poll_review_queue` y conservar nombres snake_case, por ejemplo:

- `poll_id`
- `election_key`
- `territory_code`
- `pollster_key`
- `pollster_name`
- `media`
- `fieldwork_start`
- `fieldwork_end`
- `publication_date`
- `sample_size`
- `source_url`
- `source_title`
- `wiki_page`
- `identity_status`
- `identity_confidence`
- `is_active`
- `result_count`
- `vote_share_sum`
- `anomaly_count`
- `error_count`
- `warning_count`
- `anomalies`
- `latest_identity_event_type`
- `latest_identity_event_reasons`
- `latest_review_action`
- `latest_reviewer`
- `latest_review_at`
- `review_status`
- `review_priority`

Orden recomendado:

```sql
order by review_priority desc,
         fieldwork_end desc nulls last,
         publication_date desc nulls last,
         poll_id desc
```

Implementa `total` con el mismo filtro pero sin `limit/offset`.

2. `GET /api/v1/admin/manual-review/{poll_id}`

Debe devolver una unica ficha desde `admin_poll_review_detail`.

Si no existe, responder `404`.

Debe devolver snake_case y JSON nativo para:

- `anomalies`
- `results`
- `match_candidates`
- `source_reference_ids`
- `source_metadata`
- `latest_identity_event_reasons`
- `latest_payload_json`

El frontend espera especialmente:

- `poll_id`
- `election_key`
- `pollster_name`
- `media`
- `fieldwork_start`
- `fieldwork_end`
- `publication_date`
- `sample_size`
- `source_url`
- `source_title`
- `identity_status`
- `identity_confidence`
- `vote_share_sum`
- `anomalies`
- `results`
- `match_candidates`
- `latest_identity_event_reasons`

3. `POST /api/v1/admin/manual-review/{poll_id}/actions`

Body:

```json
{
  "action": "approved_new_poll",
  "reviewer": "admin@example.com",
  "notes": "La fila coincide con la fuente.",
  "corrected_payload": {}
}
```

Acciones validas:

- `approved_new_poll`
- `approved_match`
- `rejected`
- `needs_fix`
- `comment`

Debe ejecutarse en una transaccion:

1. Bloquear la encuesta:

```sql
select id, identity_status, is_active
from polls
where id = :poll_id
for update;
```

2. Si no existe, responder `404`.

3. Mapear accion a estado:

- `approved_new_poll` -> `new_poll`
- `approved_match` -> `probable_match`
- `rejected` -> `manual_review`
- `needs_fix` -> `manual_review`
- `comment` -> mantener estado previo

4. Insertar en `poll_review_actions`:

```sql
insert into poll_review_actions
  (poll_id, action, previous_identity_status, new_identity_status, reviewer, notes, corrected_payload)
values
  (:poll_id, :action, :previous_identity_status, :new_identity_status, :reviewer, :notes, :corrected_payload::jsonb)
returning id;
```

5. Actualizar `polls`:

- `approved_new_poll` o `approved_match`:

```sql
update polls
set identity_status = :new_identity_status,
    is_active = true,
    updated_at = now()
where id = :poll_id;
```

- `rejected`:

```sql
update polls
set identity_status = 'manual_review',
    is_active = false,
    updated_at = now()
where id = :poll_id;
```

- `needs_fix`:

```sql
update polls
set identity_status = 'manual_review',
    updated_at = now()
where id = :poll_id;
```

- `comment`: no cambiar `polls`; solo registrar accion/evento.

6. Insertar evento en `poll_identity_events`:

```sql
insert into poll_identity_events
  (poll_id, wiki_revision_id, event_type, old_payload, new_payload, confidence, reasons)
select
  p.id,
  p.wiki_revision_id,
  :event_type,
  jsonb_build_object('identity_status', :previous_identity_status, 'is_active', :previous_is_active),
  jsonb_build_object('identity_status', p.identity_status, 'is_active', p.is_active, 'review_action_id', :review_action_id::bigint),
  p.identity_confidence,
  jsonb_build_array('admin_review_decision')
from polls p
where p.id = :poll_id;
```

`event_type` debe ser `manual_review_` + accion, por ejemplo `manual_review_approved_new_poll`.

Respuesta esperada:

```json
{
  "poll_id": 202,
  "review_action_id": 77,
  "action": "approved_new_poll"
}
```

Requisitos transversales:

- No cambiar endpoints publicos salvo que sea necesario.
- Mantener snake_case en JSON, porque el frontend ya consume esos nombres.
- Serializar fechas como ISO 8601.
- Serializar `numeric` como numeros JSON.
- Serializar `jsonb` como objetos/arrays JSON, no strings.
- Validar `limit` entre 1 y 1000.
- Validar `offset >= 0`.
- Validar `review_status` y `action`; devolver `422` o `400` segun convencion del framework.
- Proteger endpoints `/api/v1/admin/*` con el mecanismo de auth existente. Si la API aun no tiene auth, dejar TODO explicito y permitir configurarlo sin romper desarrollo local.
- Habilitar CORS para el origen del Admin UI en desarrollo: `http://127.0.0.1:5173`.
- Anadir tests de API para los tres endpoints, incluyendo:
  - listado paginado con filtros
  - detalle 404
  - accion invalida
  - `approved_new_poll`
  - `approved_match`
  - `rejected`
  - `needs_fix`
  - `comment`
  - insercion de `poll_review_actions`
  - insercion de `poll_identity_events`

Antes de implementar, lee:

1. `admin-ui/src/api.ts`
2. `admin-ui/src/types.ts`
3. `docs/api-handoff/api-contract-draft.md`
4. `docs/api-handoff/implementation-notes.md`
5. `sql/001_schema.sql`
6. `sql/002_indexes.sql`

Al finalizar, ejecuta los tests de la API y prueba manualmente que el Admin UI deja de usar mocks cuando `VITE_API_BASE_URL` apunta a la API real. En la ficha, comprueba que el bloque "Encuestas parecidas" recibe `match_candidates` como array y no como string.
```

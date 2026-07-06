# Database Schema Summary

Fuentes de verdad:

- `sql/001_schema.sql`
- `sql/002_indexes.sql`

## Tablas principales de dominio

### `elections`

**Uso API:** publico

Catalogo de elecciones. Clave primaria `id`; clave natural unica `election_key`. `wiki_pages.election_key` referencia `elections(election_key)` y `polls.election_id` referencia `elections(id)`.

### `pollsters`

**Uso API:** publico

Catalogo de encuestadoras normalizadas. Clave primaria `id`; clave natural unica `pollster_key`. `polls.pollster_id` referencia `pollsters(id)`.

### `parties`

**Uso API:** publico

Catalogo canonico de partidos para nombres, colores y orden de visualizacion. Clave primaria `party_key`. No hay FK desde `poll_results` para no bloquear partidos nuevos detectados por Wikipedia.

### `polls`

**Uso API:** publico con campos filtrados; interno para identidad

Entidad principal de encuesta. Clave primaria `id`. Referencias: `election_id -> elections(id)`, `pollster_id -> pollsters(id)`, `wiki_page -> wiki_pages(page_key)`. Tiene constraints sobre `identity_status`. Campos internos importantes: `poll_key_strict`, `poll_signature`, `row_hash`. Campos de fuente para API/auditoria: `source_url`, `source_title`, `source_reference_ids`, `source_metadata`.

## Tablas de resultados

### `poll_results`

**Uso API:** publico

Resultados por partido para cada encuesta en formato long. Clave primaria `id`; `poll_id -> polls(id) on delete cascade`. Constraint unico `(poll_id, party_key)`.

## Tablas de scraping y auditoria

### `wiki_pages`

**Uso API:** interno

Paginas Wikipedia configuradas como fuente. Clave primaria `id`; `page_key` unico. Referencia `elections(election_key)`.

### `wiki_page_revisions`

**Uso API:** administrativo

Snapshot de revisiones Wikipedia. Clave primaria `id`. Referencia `wiki_pages(page_key)`. Constraint unico `(page_key, revision_id)`. `parse_status` limitado a `fetched`, `success`, `failed`.

### `poll_versions`

**Uso API:** administrativo

Historico de versiones de una encuesta cuando cambia el payload normalizado. Clave primaria `id`; `poll_id -> polls(id) on delete cascade`.

### `poll_identity_events`

**Uso API:** administrativo/debug

Eventos de matching, correcciones y desactivaciones. Clave primaria `id`; `poll_id -> polls(id)` nullable.

### `scraper_runs`

**Uso API:** administrativo

Ejecuciones del scraper. Clave primaria `id`; `page_key -> wiki_pages(page_key)`. `status` limitado a `running`, `success`, `failed`, `no_change`.

### `poll_review_actions`

**Uso API:** administrativo

Registro operativo de decisiones de revision manual. Cada accion referencia `polls(id)` y guarda accion, revisor, notas, payload corregido opcional y estados de identidad antes/despues.

### `poll_match_candidates`

**Uso API:** administrativo

Candidatos de matching calculados por el ETL. Cada fila vincula una encuesta revisada con una encuesta existente parecida, junto con confianza, razones y snapshot ligero del candidato.

## Vistas publicas

### `api_polls_public`

Vista read-only recomendada para listados publicos de encuestas. Aplica `p.is_active = true` y `p.identity_status <> 'manual_review'`.

### `api_poll_results_public`

Vista read-only recomendada para series y resultados por partido. Incluye metadatos de partido desde `parties` cuando existe catalogo.

## Vistas administrativas de revision

### `admin_poll_review_queue`

Vista para la bandeja de revision manual. Incluye metadatos de encuesta, fuente, confianza de matching, recuentos de anomalias, suma de voto, estado de revision y prioridad.

### `admin_poll_review_detail`

Vista para la ficha completa de una encuesta en revision. Incluye resultados agregados en JSON, anomalias, fuente, ultimo evento de identidad y ultimo payload normalizado.

### `admin_poll_review_results`

Vista de resultados por partido para una encuesta admin. Incluye colores, indicador de partido desconocido, valor crudo y comparacion contra la media de hasta 10 encuestas recientes de la misma eleccion.

### `admin_poll_review_anomalies`

Vista normalizada de anomalias detectables por SQL: estado manual, baja confianza, fechas ausentes o incoherentes, muestra ausente, fuente ausente, partido desconocido y suma/valores de voto sospechosos.

### `admin_poll_review_match_candidates`

Vista de candidatos de matching para el bloque `Encuestas parecidas` del Admin UI. Expone confianza, razones, metadatos y resultados del snapshot guardado por el ETL.

## Tablas auxiliares

`parties` contiene el catalogo canonico. `poll_results.party_key` puede contener claves no catalogadas si Wikipedia introduce una formacion nueva antes de actualizar el catalogo.

No existe una tabla separada de medios. El medio se guarda como texto en `polls.media`; el ETL calcula un `media_key` temporal en R, pero no se almacena como columna SQL.

## Tablas internas o administrativas

Tablas normalmente no consultadas por la API publica:

- `wiki_pages`
- `wiki_page_revisions`
- `poll_versions`
- `poll_identity_events`
- `scraper_runs`
- `poll_review_actions`
- `poll_match_candidates`

## Indices importantes

Definidos en `sql/002_indexes.sql`:

- `idx_wiki_page_revisions_page_revision` en `(page_key, revision_id)`
- `idx_wiki_page_revisions_status` en `(parse_status)`
- `idx_polls_election_page` en `(election_id, wiki_page)`
- `idx_polls_public_filters` en `(election_id, is_active, identity_status, fieldwork_end desc, publication_date desc)`
- `idx_polls_pollster` en `(pollster_id)`
- `idx_polls_media` en `(media)`
- `idx_polls_signature` en `(poll_signature)`
- `idx_polls_row_hash` en `(row_hash)`
- `idx_polls_publication_date` en `(publication_date)`
- `idx_polls_source_metadata` GIN en `(source_metadata)`
- `idx_poll_results_party` en `(party_key)`
- `idx_parties_display_order` en `(is_active, display_order, party_key)`
- `idx_poll_versions_poll` en `(poll_id, valid_from desc)`
- `idx_poll_identity_events_poll` en `(poll_id, created_at desc)`
- `idx_scraper_runs_page_started` en `(page_key, started_at desc)`
- `idx_poll_review_actions_poll_created` en `(poll_id, created_at desc, id desc)`
- `idx_poll_review_actions_action_created` en `(action, created_at desc)`
- `idx_poll_match_candidates_poll_revision` en `(poll_id, wiki_revision_id, rank)`
- `idx_poll_match_candidates_candidate` en `(candidate_poll_id)`

## Constraints importantes

- `elections.election_key` unico.
- `wiki_pages.page_key` unico.
- `wiki_page_revisions(page_key, revision_id)` unico.
- `pollsters.pollster_key` unico.
- `parties.party_key` primary key.
- `polls.poll_key_strict` unico.
- `poll_results(poll_id, party_key)` unico.
- `polls.identity_status in ('exact', 'probable_match', 'manual_review', 'new_poll')`.
- `wiki_page_revisions.parse_status in ('fetched', 'success', 'failed')`.
- `scraper_runs.status in ('running', 'success', 'failed', 'no_change')`.
- `poll_review_actions.action in ('approved_new_poll', 'approved_match', 'rejected', 'needs_fix', 'comment')`.

## Notas de implementacion para la API

- No faltan tablas requeridas: `wiki_pages`, `wiki_page_revisions`, `elections`, `pollsters`, `parties`, `polls`, `poll_results`, `poll_versions`, `poll_identity_events`, `scraper_runs`, `poll_review_actions` y `poll_match_candidates` existen en las migraciones SQL.
- `publication_date` se extrae de las referencias de Wikipedia cuando hay metadata (`rft.date` o texto de fecha). Si falta, el ETL usa `fieldwork_end` como fallback.
- `source_metadata` contiene metadatos de referencia y puede crecer; exponer solo campos publicos derivados en endpoints publicos.
- `media_key` existe en la logica R para matching, pero no existe como columna SQL. La API debe filtrar por `polls.media` o proponer una migracion futura.
- `notes`, `year` y `row_number` aparecen en payloads internos del ETL, pero no existen como columnas de `polls`.
- `polls.wiki_revision_id`, `poll_versions.wiki_revision_id` y `scraper_runs.revision_id` no tienen FK SQL hacia `wiki_page_revisions`; deben tratarse como metadatos de origen, no como relacion garantizada por constraint.
- `scraper_runs` no tiene columna `polls_deactivated`, aunque `upsert_normalized_polls()` calcula esa estadistica internamente.
- Las vistas `admin_poll_review_*` son la base recomendada para pantallas administrativas visuales; la API publica debe seguir usando las vistas `api_*`.

## Posibles mejoras futuras

- Crear tabla `media_outlets` o columna `media_key` persistida.
- Anadir FK compuesta para revisar integridad de revision cuando el modelo lo permita.
- Anadir autenticacion/autorizacion concreta para endpoints admin.

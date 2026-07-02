# Database Schema Summary

Fuentes de verdad:

- `sql/001_schema.sql`
- `sql/002_indexes.sql`
- `sql/003_publication_sources.sql`

## Tablas principales de dominio

### `elections`

**Uso API:** publico

Catalogo de elecciones. Clave primaria `id`; clave natural unica `election_key`. `wiki_pages.election_key` referencia `elections(election_key)` y `polls.election_id` referencia `elections(id)`.

### `pollsters`

**Uso API:** publico

Catalogo de encuestadoras normalizadas. Clave primaria `id`; clave natural unica `pollster_key`. `polls.pollster_id` referencia `pollsters(id)`.

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

## Tablas auxiliares

No existe una tabla separada de partidos. Los partidos disponibles se derivan de `poll_results.party_key` y `poll_results.party_raw`.

No existe una tabla separada de medios. El medio se guarda como texto en `polls.media`; el ETL calcula un `media_key` temporal en R, pero no se almacena como columna SQL.

## Tablas internas o administrativas

Tablas normalmente no consultadas por la API publica:

- `wiki_pages`
- `wiki_page_revisions`
- `poll_versions`
- `poll_identity_events`
- `scraper_runs`

## Indices importantes

Definidos en `sql/002_indexes.sql` y `sql/003_publication_sources.sql`:

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
- `idx_poll_versions_poll` en `(poll_id, valid_from desc)`
- `idx_poll_identity_events_poll` en `(poll_id, created_at desc)`
- `idx_scraper_runs_page_started` en `(page_key, started_at desc)`

## Constraints importantes

- `elections.election_key` unico.
- `wiki_pages.page_key` unico.
- `wiki_page_revisions(page_key, revision_id)` unico.
- `pollsters.pollster_key` unico.
- `polls.poll_key_strict` unico.
- `poll_results(poll_id, party_key)` unico.
- `polls.identity_status in ('exact', 'probable_match', 'manual_review', 'new_poll')`.
- `wiki_page_revisions.parse_status in ('fetched', 'success', 'failed')`.
- `scraper_runs.status in ('running', 'success', 'failed', 'no_change')`.

## Notas de implementacion para la API

- No faltan tablas requeridas: `wiki_pages`, `wiki_page_revisions`, `elections`, `pollsters`, `polls`, `poll_results`, `poll_versions`, `poll_identity_events` y `scraper_runs` existen en `sql/001_schema.sql`.
- `publication_date` se extrae de las referencias de Wikipedia cuando hay metadata (`rft.date` o texto de fecha). Si falta, el ETL usa `fieldwork_end` como fallback.
- `source_metadata` contiene metadatos de referencia y puede crecer; exponer solo campos publicos derivados en endpoints publicos.
- `media_key` existe en la logica R para matching, pero no existe como columna SQL. La API debe filtrar por `polls.media` o proponer una migracion futura.
- `notes`, `year` y `row_number` aparecen en payloads internos del ETL, pero no existen como columnas de `polls`.
- `polls.wiki_revision_id`, `poll_versions.wiki_revision_id` y `scraper_runs.revision_id` no tienen FK SQL hacia `wiki_page_revisions`; deben tratarse como metadatos de origen, no como relacion garantizada por constraint.
- `scraper_runs` no tiene columna `polls_deactivated`, aunque `upsert_normalized_polls()` calcula esa estadistica internamente.

## Posibles mejoras futuras

- Crear tabla `parties` con `party_key`, nombre canonico, color y orden.
- Crear tabla `media_outlets` o columna `media_key` persistida.
- Anadir FK compuesta para revisar integridad de revision cuando el modelo lo permita.
- Anadir workflow operativo de revision manual con usuario, decision y notas.

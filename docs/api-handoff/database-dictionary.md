# Database Dictionary

Valores de `Uso API`: `public`, `internal`, `admin`, `debug`, `do_not_expose`.

## `elections`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador numerico de la eleccion. | public | Puede usarse como FK interna; exponer tambien `election_key`. |
| `election_key` | `text` | no | Clave natural unica de eleccion. | public | Ejemplo: `congreso_espana_2027`. |
| `election_type` | `text` | no | Tipo de eleccion. | public | Ejemplo: `general`. |
| `territory_code` | `text` | no | Codigo territorial. | public | Ejemplo: `ES`. |
| `election_name` | `text` | no | Nombre legible de la eleccion. | public |  |
| `election_date` | `date` | si | Fecha de eleccion si se conoce. | public | Puede ser `null` para futuras elecciones. |
| `created_at` | `timestamptz` | no | Alta del registro. | admin | Campo administrativo. |

## `wiki_pages`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador numerico. | internal |  |
| `page_key` | `text` | no | Clave unica de pagina fuente. | internal | Referenciada por `polls.wiki_page`. |
| `page_title` | `text` | no | Titulo Wikipedia. | admin |  |
| `url` | `text` | no | URL de la pagina. | admin | Puede mostrarse en endpoints admin. |
| `election_key` | `text` | no | Eleccion asociada. | internal | FK a `elections(election_key)`. |
| `territory_code` | `text` | no | Territorio de la pagina. | internal |  |
| `is_active` | `boolean` | no | Si la fuente sigue activa. | admin | No confundir con `polls.is_active`. |
| `created_at` | `timestamptz` | no | Alta del registro. | admin |  |

## `wiki_page_revisions`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador de snapshot. | admin |  |
| `page_key` | `text` | no | Pagina fuente. | admin | FK a `wiki_pages(page_key)`. |
| `revision_id` | `bigint` | no | Revision MediaWiki. | admin | Unica por `page_key`. |
| `revision_timestamp` | `timestamptz` | si | Timestamp de Wikipedia. | admin |  |
| `fetched_at` | `timestamptz` | no | Momento de descarga. | admin |  |
| `content_sha256` | `text` | si | Hash del HTML descargado. | debug | No exponer publicamente. |
| `raw_html` | `text` | si | HTML crudo. | do_not_expose | Payload interno y pesado. |
| `raw_wikitext` | `text` | si | Wikitext crudo. | do_not_expose | Payload interno y pesado. |
| `parse_status` | `text` | no | Estado de parseo. | admin | `fetched`, `success`, `failed`. |
| `error_message` | `text` | si | Error de parseo/fetch. | admin | Solo admin; puede contener detalles internos. |

## `pollsters`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador numerico. | public |  |
| `pollster_name` | `text` | no | Nombre visible de encuestadora. | public | Ejemplo: `40dB`. |
| `pollster_key` | `text` | no | Clave normalizada unica. | public | Ejemplo: `40db`. |
| `created_at` | `timestamptz` | no | Alta del registro. | admin |  |

## `parties`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `party_key` | `text` | no | Clave canonica del partido. | public | Coincide con `poll_results.party_key` cuando esta catalogado. |
| `party_name` | `text` | no | Nombre completo canonico. | public | Ejemplo: `Partido Popular`. |
| `short_name` | `text` | no | Nombre corto para UI. | public | Ejemplo: `PP`. |
| `territory_code` | `text` | no | Territorio principal del partido. | public | Ejemplo: `ES`, `ES-CT`. |
| `color_hex` | `text` | si | Color sugerido para visualizaciones. | public | Puede ser null. |
| `display_order` | `integer` | si | Orden recomendado de visualizacion. | public | Orden ascendente. |
| `is_active` | `boolean` | no | Si el partido esta activo en el catalogo. | public | No filtra resultados historicos automaticamente. |
| `created_at` | `timestamptz` | no | Alta del registro. | admin |  |

## `polls`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador numerico de encuesta. | public | Identificador publico recomendado en v1. |
| `poll_key_strict` | `text` | no | Clave determinista estricta. | internal | Usa eleccion, encuestadora, medio, fechas de campo y muestra. No usar como ID publico principal. |
| `poll_signature` | `text` | no | Firma flexible para matching. | do_not_expose | No exponer en endpoints publicos. |
| `election_id` | `bigint` | no | Eleccion asociada. | public | FK a `elections(id)`. |
| `pollster_id` | `bigint` | no | Encuestadora asociada. | public | FK a `pollsters(id)`. |
| `media` | `text` | si | Medio/comisionante visible. | public | No hay `media_key` persistido. |
| `fieldwork_start` | `date` | si | Inicio del trabajo de campo. | public | ISO 8601 en API. |
| `fieldwork_end` | `date` | si | Fin del trabajo de campo. | public | Fecha principal para series si existe. |
| `publication_date` | `date` | si | Fecha de publicacion. | public | Extraida de referencias Wikipedia cuando existe; fallback a `fieldwork_end`. |
| `sample_size` | `integer` | si | Tamano muestral. | public | Extraido como entero. |
| `turnout` | `numeric` | si | Participacion estimada. | public | Porcentaje numerico, no string. |
| `lead` | `numeric` | si | Ventaja entre primero y segundo. | public | Porcentaje numerico. |
| `wiki_page` | `text` | no | Pagina fuente. | internal | FK a `wiki_pages(page_key)`. |
| `wiki_revision_id` | `bigint` | si | Revision MediaWiki origen. | admin | No tiene FK SQL. |
| `source_url` | `text` | si | URL externa de la referencia de Wikipedia. | public | Puede ser null si la referencia no trae URL externa. |
| `source_title` | `text` | si | Titulo de la referencia usada como fuente. | public | Apto para mostrar como etiqueta de enlace. |
| `source_reference_ids` | `jsonb` | no | IDs `cite_note-*` usados por la fila. | admin | Puede exponerse en admin/debug; no necesario en listados publicos. |
| `source_metadata` | `jsonb` | no | Metadatos normalizados de las referencias de Wikipedia. | admin | Incluye URL, titulo, publisher, fecha y texto de referencia; no exponer completo en publico. |
| `row_hash` | `text` | no | Hash SHA-256 del payload normalizado. | do_not_expose | No exponer en endpoints publicos. |
| `identity_status` | `text` | no | Estado de identidad/matching. | public | Filtrar `manual_review` por defecto. |
| `identity_confidence` | `numeric` | si | Confianza del matching. | admin | Puede exponerse solo en admin/debug. |
| `first_seen_at` | `timestamptz` | no | Primera vez vista por el ETL. | public | Util para recientes. |
| `last_seen_at` | `timestamptz` | no | Ultima vez vista por el ETL. | admin |  |
| `updated_at` | `timestamptz` | no | Ultima actualizacion en DB. | admin |  |
| `is_active` | `boolean` | no | Si la encuesta sigue presente/activa. | public | `false` debe excluirse por defecto. |

## `poll_results`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador del resultado. | public |  |
| `poll_id` | `bigint` | no | Encuesta asociada. | public | FK a `polls(id)`. |
| `party_key` | `text` | no | Partido normalizado. | public | Ejemplo: `psoe`, `pp`, `vox`. |
| `party_raw` | `text` | si | Etiqueta original de Wikipedia. | public | Util para mostrar. |
| `vote_share` | `numeric` | si | Porcentaje de voto. | public | Devolver como numero. |
| `seats_min` | `integer` | si | Escanos minimos si la celda los trae. | public |  |
| `seats_max` | `integer` | si | Escanos maximos si la celda los trae. | public |  |
| `raw_value` | `text` | si | Valor original de celda. | debug | No necesario en API publica por defecto. |

## `poll_versions`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Version de encuesta. | admin |  |
| `poll_id` | `bigint` | no | Encuesta asociada. | admin | FK cascade a `polls(id)`. |
| `wiki_revision_id` | `bigint` | si | Revision MediaWiki asociada. | admin | No tiene FK SQL. |
| `row_hash` | `text` | no | Hash del payload de esa version. | do_not_expose | No exponer publicamente. |
| `payload_json` | `jsonb` | no | Payload normalizado historico. | admin | No exponer en endpoints publicos. |
| `valid_from` | `timestamptz` | no | Momento desde el que aplica la version. | admin |  |

## `poll_identity_events`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Evento de identidad. | admin |  |
| `poll_id` | `bigint` | si | Encuesta asociada. | admin | Nullable para eventos sin encuesta final. |
| `wiki_revision_id` | `bigint` | si | Revision MediaWiki. | admin |  |
| `event_type` | `text` | no | Tipo de evento. | admin | Ejemplos: `exact_match`, `probable_match`, `manual_review`, `poll_missing_from_revision`. |
| `old_payload` | `jsonb` | si | Payload anterior. | do_not_expose | Interno. |
| `new_payload` | `jsonb` | si | Payload nuevo. | do_not_expose | Interno. |
| `confidence` | `numeric` | si | Confianza de matching. | debug |  |
| `reasons` | `jsonb` | si | Razones del matching. | debug | No exponer publicamente. |
| `created_at` | `timestamptz` | no | Momento del evento. | admin |  |

## `scraper_runs`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Ejecucion del scraper. | admin |  |
| `started_at` | `timestamptz` | no | Inicio. | admin |  |
| `finished_at` | `timestamptz` | si | Fin. | admin |  |
| `status` | `text` | no | Estado. | admin | `running`, `success`, `failed`, `no_change`. |
| `page_key` | `text` | si | Pagina scrapeada. | admin | FK a `wiki_pages(page_key)`. |
| `revision_id` | `bigint` | si | Revision MediaWiki. | admin | No tiene FK SQL. |
| `rows_found` | `integer` | si | Filas parseadas. | admin | Default `0`. |
| `polls_inserted` | `integer` | si | Encuestas insertadas. | admin | Default `0`. |
| `polls_updated` | `integer` | si | Encuestas actualizadas. | admin | Default `0`. |
| `polls_unchanged` | `integer` | si | Encuestas sin cambios. | admin | Default `0`. |
| `polls_manual_review` | `integer` | si | Encuestas en revision manual. | admin | Default `0`. |
| `error_message` | `text` | si | Error de ejecucion. | admin | Puede contener detalles internos. |

## `poll_review_actions`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador de accion de revision. | admin |  |
| `poll_id` | `bigint` | no | Encuesta revisada. | admin | FK a `polls(id)` con cascade. |
| `action` | `text` | no | Decision registrada por administracion. | admin | `approved_new_poll`, `approved_match`, `rejected`, `needs_fix`, `comment`. |
| `previous_identity_status` | `text` | si | Estado de identidad antes de la accion. | admin | Copia auditada desde `polls.identity_status`. |
| `new_identity_status` | `text` | si | Estado de identidad despues de la accion. | admin | Puede ser igual al anterior para comentarios o rechazos. |
| `reviewer` | `text` | si | Usuario/persona que revisa. | admin | Formato libre; la API puede usar email o id interno. |
| `notes` | `text` | si | Notas internas de revision. | admin | No exponer publicamente. |
| `corrected_payload` | `jsonb` | no | Correcciones propuestas o aplicadas desde la pantalla. | admin | Default `{}`. |
| `created_at` | `timestamptz` | no | Momento de la accion. | admin |  |

## `poll_match_candidates`

| Columna | Tipo | Nullable | Descripcion | Uso API | Notas |
|---|---|---:|---|---|---|
| `id` | `bigserial` | no | Identificador interno del candidato. | admin |  |
| `poll_id` | `bigint` | no | Encuesta revisada o actualizada. | admin | FK a `polls(id)`. |
| `candidate_poll_id` | `bigint` | no | Encuesta existente considerada parecida. | admin | FK a `polls(id)`. |
| `wiki_revision_id` | `bigint` | si | Revision en la que se calculo el matching. | admin | No tiene FK SQL. |
| `rank` | `integer` | no | Orden del candidato por confianza. | admin | 1 es el candidato mas parecido. |
| `confidence` | `numeric` | si | Puntuacion de matching. | admin | 0-1. |
| `reasons` | `jsonb` | no | Razones que explican la similitud. | admin | Array JSON. |
| `candidate_snapshot` | `jsonb` | no | Snapshot ligero del candidato en el momento del matching. | admin | Evita recalcular historico. |
| `created_at` | `timestamptz` | no | Momento de persistencia. | admin |  |

## `api_polls_public`

Vista publica de encuestas activas y no ambiguas. Equivale a `polls` unido con `elections` y `pollsters`, filtrando `is_active = true` e `identity_status <> 'manual_review'`.

## `api_poll_results_public`

Vista publica de resultados long. Une `polls`, `poll_results`, `elections`, `pollsters` y `parties`, filtrando encuestas inactivas y `manual_review`.

## `admin_poll_review_queue`

Vista administrativa para la bandeja visual de revision. Incluye prioridad, estado de revision, metadatos de encuesta, fuente, confianza, suma de voto y anomalias agregadas.

## `admin_poll_review_detail`

Vista administrativa para la ficha visual de revision. Incluye resultados agregados, anomalias, source metadata, ultimo evento de identidad y ultimo payload normalizado.

## `admin_poll_review_results`

Vista administrativa long de resultados por partido. Incluye colores, indicador de partido desconocido, `raw_value` y delta frente a la media reciente.

## `admin_poll_review_anomalies`

Vista administrativa de anomalias por encuesta. Cada fila incluye `poll_id`, `severity`, `anomaly_code` y `message`.

## `admin_poll_review_match_candidates`

Vista administrativa de candidatos de matching. Expone `candidate_poll_id`, `confidence`, `reasons`, metadatos del snapshot y resultados principales para pintar el bloque `Encuestas parecidas`.

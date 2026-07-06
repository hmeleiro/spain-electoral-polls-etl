# API Use Cases

## Caso de uso: Mostrar evolucion del voto por partido

### Descripcion
Serie temporal de `vote_share` para uno o varios partidos.
### Tablas implicadas
`polls`, `poll_results`, `elections`, `pollsters`.
### Filtros necesarios
`election_key`, `territory_code`, `party_key`, `fieldwork_start`, `fieldwork_end`, `publication_date`.
### Campos de salida esperados
`poll_id`, `date`, `party_key`, `party_raw`, `party_name`, `short_name`, `color_hex`, `vote_share`, `pollster_name`, `media`, `sample_size`.
### Notas para la API
Aplicar por defecto `is_active = true` y excluir `manual_review`.

## Caso de uso: Mostrar evolucion del voto filtrada por encuestadora

### Descripcion
Serie temporal limitada a una o varias encuestadoras.
### Tablas implicadas
`polls`, `poll_results`, `pollsters`, `elections`.
### Filtros necesarios
`pollster_key`, `pollster_id`, `election_key`, `party_key`.
### Campos de salida esperados
`poll_id`, `date`, `pollster_key`, `pollster_name`, `party_key`, `vote_share`.
### Notas para la API
Filtrar en SQL por `polls.pollster_id` tras resolver `pollster_key`.

## Caso de uso: Mostrar evolucion del voto filtrada por medio

### Descripcion
Serie temporal limitada por `polls.media`.
### Tablas implicadas
`polls`, `poll_results`, `elections`.
### Filtros necesarios
`media`, fechas, eleccion, partido.
### Campos de salida esperados
`poll_id`, `date`, `media`, `party_key`, `vote_share`.
### Notas para la API
No existe `media_key` SQL; evitar prometer filtros canonicos hasta migracion futura.

## Caso de uso: Mostrar ficha completa de una encuesta

### Descripcion
Detalle de una encuesta con metadatos y todos sus resultados.
### Tablas implicadas
`polls`, `poll_results`, `pollsters`, `elections`.
### Filtros necesarios
`poll_id`; opcionalmente `include_inactive`, `include_manual_review`.
### Campos de salida esperados
Metadatos de encuesta, `source_url`, `source_title` y array `results`.
### Notas para la API
No incluir `row_hash`, `poll_signature` ni `source_metadata` completo en respuesta publica.

## Caso de uso: Listar encuestas recientes

### Descripcion
Listado paginado ordenado por `fieldwork_end`, `publication_date` o `first_seen_at`.
### Tablas implicadas
`polls`, `pollsters`, `elections`.
### Filtros necesarios
`limit`, `offset`, `election_key`, `pollster_key`, `media`.
### Campos de salida esperados
`id`, `election_key`, `pollster_name`, `media`, fechas, `sample_size`, `lead`, `is_active`.
### Notas para la API
Usar paginacion y `max_limit = 1000`.

## Caso de uso: Filtrar encuestas por rango de fechas

### Descripcion
Obtener encuestas cuyo trabajo de campo o publicacion caiga en un rango.
### Tablas implicadas
`polls`, `elections`, `pollsters`.
### Filtros necesarios
`fieldwork_start_from`, `fieldwork_end_to`, `publication_date_from`, `publication_date_to`.
### Campos de salida esperados
Metadatos de encuesta.
### Notas para la API
Aplicar filtros en SQL, preferentemente sobre `fieldwork_end` para series.

## Caso de uso: Auditar fuente y fecha de publicacion

### Descripcion
Consultar la referencia Wikipedia de la que salieron `publication_date`, `source_url` y `source_title`.
### Tablas implicadas
`polls`.
### Filtros necesarios
`poll_id`.
### Campos de salida esperados
`poll_id`, `source_url`, `source_title`, `source_reference_ids`, `source_metadata`.
### Notas para la API
Endpoint administrativo/debug; `source_metadata.reference_text` puede ser largo y no debe ir en listados publicos.

## Caso de uso: Comparar encuestadoras

### Descripcion
Comparar estimaciones de uno o varios partidos entre encuestadoras.
### Tablas implicadas
`polls`, `poll_results`, `pollsters`, `elections`.
### Filtros necesarios
`pollster_key`, `party_key`, fechas, eleccion.
### Campos de salida esperados
`pollster_key`, `pollster_name`, `date`, `party_key`, `vote_share`, `sample_size`.
### Notas para la API
Puede implementarse con `/api/v1/timeseries`.

## Caso de uso: Listar partidos disponibles

### Descripcion
Catalogo canonico de partidos soportados por el sistema.
### Tablas implicadas
`parties`, opcionalmente `poll_results`, `polls`, `elections` para conteos.
### Filtros necesarios
`election_key`, `active_only`.
### Campos de salida esperados
`party_key`, `party_name`, `short_name`, `territory_code`, `color_hex`, `display_order`, opcionalmente `poll_count`.
### Notas para la API
Usar `parties` como fuente canonica; si se calculan conteos, unir con resultados mediante `left join`.

## Caso de uso: Listar encuestadoras disponibles

### Descripcion
Catalogo de encuestadoras con conteo opcional de encuestas.
### Tablas implicadas
`pollsters`, `polls`.
### Filtros necesarios
`election_key`, `active_only`.
### Campos de salida esperados
`id`, `pollster_key`, `pollster_name`, `poll_count`.
### Notas para la API
Puede incluir encuestadoras sin encuestas si se consulta catalogo puro.

## Caso de uso: Listar elecciones disponibles

### Descripcion
Catalogo de elecciones configuradas.
### Tablas implicadas
`elections`, `wiki_pages`.
### Filtros necesarios
`territory_code`, `election_type`.
### Campos de salida esperados
`id`, `election_key`, `election_type`, `territory_code`, `election_name`, `election_date`.
### Notas para la API
Endpoint publico.

## Caso de uso: Consultar solo encuestas activas

### Descripcion
Vista publica por defecto.
### Tablas implicadas
`polls`.
### Filtros necesarios
`is_active = true`.
### Campos de salida esperados
Metadatos publicos.
### Notas para la API
Debe ser comportamiento default, no una excepcion.

## Caso de uso: Consultar casos en revision manual para depuracion

### Descripcion
Listado visual de encuestas ambiguas o con anomalias para revision administrativa.
### Tablas implicadas
Preferentemente `admin_poll_review_queue`; internamente usa `polls`, `pollsters`, `elections`, `poll_identity_events`, `poll_review_actions` y vistas de anomalias.
### Filtros necesarios
`election_key`, `page_key`, `review_status`, `limit`, `offset`.
### Campos de salida esperados
Metadatos, fuente, `identity_confidence`, conteo de anomalias, `review_status`, `review_priority`, eventos recientes y array `anomalies`.
### Notas para la API
Endpoint administrativo consumido por `admin-ui/`. Debe devolver respuesta paginada con `items`, `limit`, `offset`, `total`.

## Caso de uso: Revisar visualmente una encuesta concreta

### Descripcion
Ficha de revision con resultados, anomalias, fuente y razones de matching.
### Tablas implicadas
Preferentemente `admin_poll_review_detail`.
### Filtros necesarios
`poll_id`.
### Campos de salida esperados
Metadatos completos de la encuesta, `anomalies`, `results`, `match_candidates`, `source_metadata`, `latest_identity_event_reasons`, `latest_payload_json`.
### Notas para la API
Endpoint administrativo consumido por `admin-ui/`. Devolver `404` si no existe la encuesta.

## Caso de uso: Registrar decision de revision manual

### Descripcion
Guardar la decision de un administrador y actualizar la visibilidad de la encuesta cuando proceda.
### Tablas implicadas
`polls`, `poll_review_actions`, `poll_identity_events`.
### Filtros necesarios
`poll_id`.
### Campos de entrada esperados
`action`, `reviewer`, `notes`, `corrected_payload`.
### Campos de salida esperados
`poll_id`, `review_action_id`, `action`.
### Notas para la API
Debe ser transaccional. Acciones validas: `approved_new_poll`, `approved_match`, `rejected`, `needs_fix`, `comment`.

## Caso de uso: Consultar historico de versiones de una encuesta para auditoria

### Descripcion
Ver cambios de payload normalizado.
### Tablas implicadas
`poll_versions`, `polls`.
### Filtros necesarios
`poll_id`.
### Campos de salida esperados
`id`, `poll_id`, `wiki_revision_id`, `valid_from`, `payload_json`.
### Notas para la API
Endpoint administrativo; no exponer en publico.

## Caso de uso: Consultar ejecuciones del scraper para monitorizacion

### Descripcion
Monitorizar ultimas ejecuciones y errores.
### Tablas implicadas
`scraper_runs`, `wiki_pages`.
### Filtros necesarios
`page_key`, `status`, rango de `started_at`.
### Campos de salida esperados
`id`, `started_at`, `finished_at`, `status`, contadores, `error_message`.
### Notas para la API
Endpoint administrativo protegido.

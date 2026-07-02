# API handoff: Spain Electoral Polls

Esta carpeta documenta el estado actual del ETL y del esquema PostgreSQL para que otro agente pueda implementar una API en Python/FastAPI sin tener que leer todo el codigo R.

La base de datos esperada se llama `spainelectoralpollsdb`. Las fuentes de verdad del esquema son:

- `sql/001_schema.sql`
- `sql/002_indexes.sql`
- `sql/003_publication_sources.sql`

## Documentos incluidos

- `database-schema-summary.md`: resumen del esquema, tablas, relaciones, indices y discrepancias.
- `database-dictionary.md`: diccionario completo de tablas y columnas.
- `entity-relationship.md`: relaciones entre entidades y diagrama Mermaid.
- `business-rules.md`: reglas de negocio que la API debe respetar.
- `api-use-cases.md`: casos de uso esperados del dashboard y de endpoints administrativos.
- `api-contract-draft.md`: contrato inicial sugerido para FastAPI.
- `sample-data.md`: filas y respuestas JSON realistas.
- `implementation-notes.md`: notas tecnicas para implementar la API.

## Orden recomendado de lectura para el agente de la API

1. `database-schema-summary.md`
2. `database-dictionary.md`
3. `entity-relationship.md`
4. `business-rules.md`
5. `api-use-cases.md`
6. `api-contract-draft.md`
7. `sample-data.md`
8. `implementation-notes.md`

## Partes del ETL relevantes para la API

- `R/wiki_fetch.R`: obtiene `revision_id`, HTML y wikitext de Wikipedia.
- `R/wiki_parse.R`: detecta tablas nacionales de intencion de voto, extrae filas y resuelve referencias `cite_note-*` para obtener fecha/titulo/URL de publicacion.
- `R/normalize_polls.R`: normaliza fechas, encuestadoras, medios, partidos, porcentajes, escanos y metadatos de fuente.
- `R/poll_matching.R`: genera `poll_key_strict`, `poll_signature`, `row_hash` y decide identidad (`exact`, `probable_match`, `manual_review`, `new_poll`).
- `R/db_upsert.R`: inserta/actualiza `polls`, `poll_results`, `poll_versions`, `poll_identity_events`, `wiki_page_revisions` y `scraper_runs`.

## Partes del ETL que no deberian exponerse directamente

No expongas en endpoints publicos:

- `row_hash`
- `poll_signature`
- `payload_json`
- `old_payload`
- `new_payload`
- `reasons`
- HTML o wikitext crudo de Wikipedia
- trazas internas de matching
- errores internos del scraper salvo endpoints administrativos protegidos

La API publica debe consultar principalmente `elections`, `pollsters`, `polls` y `poll_results`, aplicando por defecto `polls.is_active = true` y `polls.identity_status <> 'manual_review'`.

El ETL ya tiene configuradas al menos dos paginas nacionales: `next_spanish_general_election` y `spanish_general_election_2023`. La API no debe asumir que solo existe una eleccion o una pagina fuente.

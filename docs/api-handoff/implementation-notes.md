# Implementation Notes

## Tablas para la API publica

Consultar normalmente:

- `elections`
- `pollsters`
- `polls`
- `poll_results`

## Tablas reservadas para endpoints administrativos

- `wiki_pages`
- `wiki_page_revisions`
- `poll_versions`
- `poll_identity_events`
- `scraper_runs`

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
from polls p
join elections e on e.id = p.election_id
join pollsters ps on ps.id = p.pollster_id
```

Resultados long:

```sql
from poll_results pr
join polls p on p.id = pr.poll_id
join elections e on e.id = p.election_id
join pollsters ps on ps.id = p.pollster_id
```

Ficha completa:

```sql
from polls p
join elections e on e.id = p.election_id
join pollsters ps on ps.id = p.pollster_id
left join poll_results pr on pr.poll_id = p.id
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
- `/api/v1/parties` si se calcula agregando todo el historico repetidamente.
- Endpoints admin de `poll_versions` si `payload_json` crece.

## Decisiones abiertas

- Tabla canonica de partidos y colores.
- Persistir `media_key`.
- Autenticacion y autorizacion para `/admin`.
- Politica exacta de exposicion de `identity_status`.
- Workflow de resolucion de `manual_review`.

## Supuestos que no debe hacer el agente de la API

- No asumir que `publication_date` coincide con `fieldwork_end`.
- No asumir que solo existe una pagina/election: ya hay fuentes para `next_spanish_general_election` y `spanish_general_election_2023`.
- No asumir que existe una tabla `parties`.
- No asumir que existe una columna `media_key`.
- No asumir que `wiki_revision_id` tiene FK a `wiki_page_revisions`.
- No asumir que `manual_review` es apto para dashboard publico.
- No asumir que `raw_value` es necesario para usuarios finales.
- No modificar datos desde la API v1.

## Checklist para el agente de la API

- Revisar `sql/001_schema.sql`, `sql/002_indexes.sql` y `sql/003_publication_sources.sql`.
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

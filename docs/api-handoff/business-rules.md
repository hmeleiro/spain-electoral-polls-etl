# Business Rules

1. Por defecto, la API debe devolver solo encuestas con `polls.is_active = true`.
2. Por defecto, la API debe excluir encuestas con `polls.identity_status = 'manual_review'`.
3. Los endpoints publicos no deben exponer `row_hash`, `poll_signature`, `payload_json`, `old_payload`, `new_payload`, `reasons`, HTML/wikitext crudo ni trazas internas de matching.
4. Para series temporales, la fecha por defecto recomendada debe ser `fieldwork_end`; permitir `date_field=publication_date` para graficos por fecha de publicacion.
5. Los resultados de voto deben devolverse como numeros JSON, no strings con `%`.
6. Las fechas deben devolverse en formato ISO 8601 (`YYYY-MM-DD` para fechas, timestamp ISO para `timestamptz`).
7. Los resultados deben poder consultarse en formato long: una fila por encuesta y partido.
8. La ficha de una encuesta debe poder devolver metadatos y resultados juntos.
9. Las encuestas marcadas como `manual_review` solo deberian aparecer si se solicita explicitamente, por ejemplo `include_manual_review=true`.
10. Las encuestas inactivas solo deberian aparecer si se solicita explicitamente, por ejemplo `include_inactive=true`.
11. La API debe estar preparada para filtrar por eleccion, territorio, encuestadora, medio, partido, fechas de campo, fecha de publicacion y estado de identidad.
12. No debe hacerse filtrado masivo en memoria si puede hacerse en SQL.
13. La API no debe modificar datos en esta primera version; todos los endpoints son `GET`.
14. `poll_key_strict` puede usarse internamente para trazabilidad, pero no como identificador principal publico.
15. `polls.id` es el identificador publico recomendado para `/api/v1/polls/{poll_id}` en v1.
16. `raw_value` puede ser util para depuracion, pero la respuesta publica debe priorizar `vote_share`, `seats_min` y `seats_max`.
17. `publication_date` debe tratarse como fecha real de publicacion cuando viene de referencias; si no hay referencia con fecha, puede ser fallback a `fieldwork_end`.
18. La respuesta publica puede exponer `source_url` y `source_title`; no debe exponer `source_metadata` completo salvo endpoints admin/debug.

## Reglas dudosas o pendientes de decision

- Si `identity_status = 'new_poll'` debe tratarse publicamente igual que `exact` y `probable_match`. Recomendacion actual: si `is_active = true`, incluirlo salvo que haya politica posterior distinta.
- Como representar medios de forma canonica. Hoy solo existe `polls.media`; no existe `media_key` SQL.
- Si crear una tabla `parties` con metadatos de partido. Hoy la lista se deriva de `poll_results`.
- Si exponer `identity_status` en respuestas publicas. Recomendacion: si se expone, hacerlo como metadato simple y no incluir `identity_confidence`.
- Si endpoints administrativos requeriran autenticacion desde la primera version. Recomendacion: si existen, protegerlos.
- Como corregir manualmente una encuesta marcada `manual_review`. El esquema actual no define tabla de decisiones humanas.

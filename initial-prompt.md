Quiero que implementes el MVP técnico de un nuevo proyecto llamado **Spain Electoral Polls**, dentro del ecosistema **Spain Electoral Project**.

El objetivo inicial es construir un scraper robusto en R y una base de datos PostgreSQL llamada `spainelectoralpollsdb` para almacenar encuestas electorales publicadas en Wikipedia.

## Alcance inicial

Empieza solo con las encuestas nacionales de España posteriores a las elecciones generales de 2023, disponibles en esta página:

`https://en.wikipedia.org/wiki/Opinion_polling_for_the_next_Spanish_general_election`

Más adelante el sistema deberá poder ampliarse a encuestas autonómicas, municipales y otras páginas de Wikipedia, por lo que el diseño debe ser modular y extensible.

## Objetivos del MVP

Implementar:

1. Un scraper en R que consulte la página de Wikipedia.
2. Un sistema de detección de cambios usando la API de MediaWiki y el `revision_id` de la página.
3. Un parser de las tablas de encuestas.
4. Un normalizador de datos.
5. Un esquema PostgreSQL para almacenar:

   * páginas scrapeadas;
   * revisiones de Wikipedia;
   * encuestas;
   * resultados por partido;
   * historial de versiones;
   * eventos de identificación/matching;
   * ejecuciones del scraper.
6. Un mecanismo de `upsert` que:

   * inserte encuestas nuevas;
   * actualice encuestas ya existentes cuando Wikipedia corrija datos;
   * no duplique encuestas ya procesadas;
   * conserve historial de cambios;
   * marque para revisión manual los casos ambiguos.
7. Tests básicos del parser, del normalizador y del sistema de matching.
8. Un workflow de GitHub Actions para ejecutar el scraper dos veces al día y también manualmente.

## Requisitos tecnológicos

Usa R como lenguaje principal.

Usa preferentemente estos paquetes:

* `httr2`
* `jsonlite`
* `rvest`
* `xml2`
* `dplyr`
* `tidyr`
* `stringr`
* `lubridate`
* `janitor`
* `DBI`
* `RPostgres`
* `glue`
* `digest`
* `logger` o `cli`
* `testthat`
* `renv`

Usa PostgreSQL como base de datos.

No uses scraping frágil basado únicamente en posiciones absolutas de columnas sin validación. El scraper debe tolerar cambios moderados en la estructura de la tabla.

## Estructura esperada del repositorio

Crea una estructura similar a esta:

```text
spain-electoral-polls/
├── R/
│   ├── wiki_fetch.R
│   ├── wiki_parse.R
│   ├── normalize_polls.R
│   ├── poll_matching.R
│   ├── db_connect.R
│   ├── db_upsert.R
│   ├── run_pipeline.R
│   └── utils.R
├── scripts/
│   └── run_scraper.R
├── sql/
│   ├── 001_schema.sql
│   └── 002_indexes.sql
├── tests/
│   └── testthat/
├── .github/
│   └── workflows/
│       └── scrape-polls.yml
├── renv.lock
├── DESCRIPTION
├── README.md
└── .env.example
```

## Diseño de base de datos

Implementa al menos estas tablas.

### `wiki_pages`

Campos sugeridos:

* `id`
* `page_key`
* `page_title`
* `url`
* `election_key`
* `territory_code`
* `is_active`
* `created_at`

### `wiki_page_revisions`

Campos sugeridos:

* `id`
* `page_key`
* `revision_id`
* `revision_timestamp`
* `fetched_at`
* `content_sha256`
* `raw_html`
* `raw_wikitext`
* `parse_status`
* `error_message`

### `elections`

Campos sugeridos:

* `id`
* `election_key`
* `election_type`
* `territory_code`
* `election_name`
* `election_date`

Para el MVP crea una elección inicial:

* `election_key`: `congreso_espana_2027`
* `election_type`: `general`
* `territory_code`: `ES`
* `election_name`: `Next Spanish general election`

### `pollsters`

Campos sugeridos:

* `id`
* `pollster_name`
* `pollster_key`

### `polls`

Campos sugeridos:

* `id`
* `poll_key_strict`
* `poll_signature`
* `election_id`
* `pollster_id`
* `media`
* `fieldwork_start`
* `fieldwork_end`
* `publication_date`
* `sample_size`
* `turnout`
* `lead`
* `wiki_page`
* `wiki_revision_id`
* `source_url`
* `row_hash`
* `identity_status`
* `identity_confidence`
* `first_seen_at`
* `last_seen_at`
* `updated_at`
* `is_active`

`identity_status` debe poder tomar valores como:

```text
exact
probable_match
manual_review
new_poll
```

### `poll_results`

Campos sugeridos:

* `id`
* `poll_id`
* `party_key`
* `party_raw`
* `vote_share`
* `seats_min`
* `seats_max`
* `raw_value`

Debe existir una restricción única sobre:

```sql
unique (poll_id, party_key)
```

### `poll_versions`

Campos sugeridos:

* `id`
* `poll_id`
* `wiki_revision_id`
* `row_hash`
* `payload_json`
* `valid_from`

Esta tabla debe guardar el histórico de cambios de cada encuesta.

Cuando una encuesta existente cambie, debe guardarse el payload anterior y/o el payload nuevo para poder auditar qué dato fue corregido.

### `poll_identity_events`

Crea una tabla para auditar las decisiones de emparejamiento entre una fila scrapeada y una encuesta ya existente.

```sql
create table poll_identity_events (
  id bigserial primary key,
  poll_id bigint references polls(id),
  wiki_revision_id bigint,
  event_type text not null,
  old_payload jsonb,
  new_payload jsonb,
  confidence numeric,
  reasons jsonb,
  created_at timestamptz not null default now()
);
```

Ejemplos de `event_type`:

```text
exact_match
probable_match
manual_review
new_poll
fieldwork_dates_corrected
sample_size_corrected
vote_share_corrected
pollster_name_corrected
```

### `scraper_runs`

Campos sugeridos:

* `id`
* `started_at`
* `finished_at`
* `status`
* `page_key`
* `revision_id`
* `rows_found`
* `polls_inserted`
* `polls_updated`
* `polls_unchanged`
* `polls_manual_review`
* `error_message`

## Lógica de scraping

Implementa una función principal:

```r
run_poll_scraper(page_key = "next_spanish_general_election")
```

El flujo debe ser:

1. Cargar configuración.
2. Conectar a PostgreSQL.
3. Consultar la API de MediaWiki para obtener la última revisión de la página.
4. Comprobar si esa `revision_id` ya fue procesada correctamente.
5. Si ya fue procesada, registrar una ejecución con estado `no_change` y terminar.
6. Si es una revisión nueva:

   * descargar HTML y, si es razonable, wikitext;
   * guardar snapshot bruto en `wiki_page_revisions`;
   * parsear las tablas relevantes;
   * normalizar los registros;
   * generar `poll_key_strict`;
   * generar `poll_signature`;
   * generar `row_hash`;
   * buscar si cada encuesta ya existe usando `match_existing_poll()`;
   * insertar encuestas nuevas;
   * actualizar encuestas existentes cuando haya cambios;
   * insertar o actualizar resultados en `poll_results`;
   * crear registros en `poll_versions` cuando cambie una encuesta existente;
   * crear registros en `poll_identity_events` para auditar las decisiones de matching;
   * marcar como `manual_review` los casos ambiguos;
   * registrar estadísticas en `scraper_runs`.

## Identificación de encuestas

No asumas que `fieldwork_start` y `fieldwork_end` son siempre estables, porque Wikipedia puede corregir fechas de campo después de publicar una encuesta.

Implementa un sistema de identificación en dos niveles.

### 1. `poll_key_strict`

Clave determinista basada en metadatos normalizados.

Puede construirse con:

```text
election_key + pollster + media + fieldwork_start + fieldwork_end + sample_size
```

Ejemplo:

```text
congreso_espana_2027__40db__elpais__2026-06-01__2026-06-05__1200
```

Esta clave sirve para coincidencias exactas, pero no debe ser la única forma de decidir que una encuesta ya existe.

### 2. `poll_signature`

Firma flexible para buscar encuestas probablemente equivalentes aunque haya pequeñas correcciones.

Puede construirse con campos más estables:

```text
election_key + pollster + media + sample_size + publication_date
```

O con una variante suficientemente estable que no dependa obligatoriamente de las fechas de campo.

El objetivo de `poll_signature` no es imponer una unicidad perfecta, sino ayudar a encontrar posibles coincidencias.

## Matching flexible de encuestas

Implementa una función principal:

```r
match_existing_poll(new_poll, existing_polls)
```

Esta función debe intentar emparejar una nueva fila parseada con encuestas ya existentes.

Debe devolver algo similar a:

```r
list(
  poll_id = 123,
  match_type = "probable_match",
  confidence = 0.92,
  reasons = c(
    "same_pollster",
    "same_media",
    "same_sample_size",
    "close_publication_date"
  )
)
```

La lógica debe ser:

1. Buscar coincidencia exacta por `poll_key_strict`.
2. Si no existe, buscar coincidencias probables usando:

   * misma elección;
   * misma encuestadora normalizada;
   * mismo medio normalizado, si existe;
   * misma fecha de publicación o fecha cercana;
   * misma muestra o muestra muy parecida;
   * fechas de campo iguales o cercanas, pero no obligatorias;
   * resultados de voto suficientemente parecidos, pero nunca como único criterio.
3. Si hay una única coincidencia probable con confianza alta, actualizar la encuesta existente.
4. Si hay varias coincidencias posibles o confianza baja, insertar o marcar la fila con `identity_status = 'manual_review'`.
5. Si no hay ninguna coincidencia probable, insertar una encuesta nueva con `identity_status = 'new_poll'`.

Reglas orientativas para el matching:

* Misma encuestadora normalizada: señal fuerte.
* Mismo medio: señal media/fuerte.
* Misma muestra exacta: señal fuerte.
* Muestra muy parecida: señal media.
* Misma fecha de publicación: señal fuerte.
* Fecha de publicación cercana: señal media.
* Fechas de campo cercanas: señal media.
* Fechas de campo distintas pero cercanas: no debe impedir el match.
* Resultados de voto parecidos: señal auxiliar.
* Resultados de voto distintos: puede indicar corrección, no necesariamente nueva encuesta.
* Si dos encuestas de la misma encuestadora son muy próximas en el tiempo, evita actualizaciones automáticas agresivas y marca `manual_review`.

Casos especialmente importantes:

* Si cambia solo un porcentaje de voto, debe tratarse como corrección.
* Si cambian las fechas de campo, pero coinciden encuestadora, medio, muestra y fecha de publicación, debe tratarse como probable corrección.
* Si cambia la muestra, pero el resto coincide claramente, debe tratarse como probable corrección.
* Si hay dos encuestas distintas de la misma encuestadora en fechas cercanas, no fuerces el match: marca para revisión manual.

## Hash de fila

Crea un `row_hash` con todos los campos normalizados relevantes:

* encuestadora;
* medio;
* fechas de campo;
* fecha de publicación;
* muestra;
* turnout;
* lead;
* resultados por partido;
* fuente;
* notas si existen.

Si una encuesta existente mantiene su identidad pero cambia el `row_hash`, el scraper debe actualizar la encuesta y guardar una versión en `poll_versions`.

El `row_hash` sirve para detectar cambios de contenido, no para decidir por sí solo la identidad de la encuesta.

## Normalización de nombres

Normaliza textos antes de generar claves o comparar registros:

* minúsculas;
* sin acentos;
* sin espacios dobles;
* sin caracteres raros;
* nombres de encuestadora limpios;
* nombres de medios limpios;
* partidos mapeados a claves estables.

Implementa funciones específicas:

```r
normalize_text()
normalize_pollster()
normalize_media()
normalize_party()
```

## Normalización de partidos

Para el MVP, crea un diccionario inicial de partidos nacionales y regionales que aparecen en la tabla:

* `PSOE`
* `PP`
* `Vox`
* `Sumar`
* `Podemos`
* `ERC`
* `Junts`
* `EH Bildu`
* `EAJ/PNV`
* `BNG`
* `CCa`
* `UPN`
* `PACMA`
* `Others`

El parser debe conservar también el nombre bruto de la columna por si aparece una formación nueva.

## Tratamiento de valores especiales

El parser debe convertir correctamente:

* `–` a `NA`
* `—` a `NA`
* vacío a `NA`
* `?` a `NA`
* porcentajes como texto a numérico
* muestras con separador de miles a entero
* fechas tipo `1–5 Jun` a rango de fechas
* fechas con año implícito usando el contexto de la tabla o de la fila
* footnotes o referencias de Wikipedia eliminadas del valor limpio, pero conservadas si resultan útiles como metadata

## Robustez

El scraper debe ser resistente a errores.

Requisitos:

* usar timeouts;
* usar reintentos con backoff;
* no romper todo el pipeline por una fila mal parseada;
* registrar errores por fila cuando sea necesario;
* guardar la revisión bruta aunque el parseo falle;
* validar que se han detectado tablas de encuestas;
* validar que el número de encuestas parseadas es mayor que cero;
* validar que las fechas son coherentes;
* validar que los porcentajes están entre 0 y 100;
* validar que no hay duplicados exactos de `poll_key_strict`;
* registrar toda ejecución en `scraper_runs`;
* marcar para revisión manual los casos ambiguos en vez de tomar decisiones destructivas.

## GitHub Actions

Crea un workflow `.github/workflows/scrape-polls.yml` que:

* se pueda ejecutar manualmente con `workflow_dispatch`;
* se ejecute dos veces al día con `schedule`;
* instale R;
* restaure dependencias con `renv`;
* ejecute `scripts/run_scraper.R`;
* use secretos de GitHub para la conexión a PostgreSQL.

Variables de entorno esperadas:

```text
PGHOST
PGPORT
PGDATABASE
PGUSER
PGPASSWORD
WIKI_USER_AGENT
```

Incluye un `.env.example` con esas variables, sin credenciales reales.

## README

Documenta:

1. Qué hace el proyecto.
2. Cómo instalar dependencias.
3. Cómo crear la base de datos.
4. Cómo ejecutar las migraciones SQL.
5. Cómo lanzar el scraper manualmente.
6. Cómo configurar GitHub Actions.
7. Cómo funciona la detección de cambios por `revision_id`.
8. Cómo funciona `poll_key_strict`.
9. Cómo funciona `poll_signature`.
10. Cómo funciona el matching flexible.
11. Cómo funciona el histórico de versiones.
12. Cómo se revisan manualmente los casos ambiguos.
13. Limitaciones conocidas del MVP.

## Tests

Crea tests con `testthat` para:

* normalización de nombres;
* normalización de encuestadoras;
* normalización de medios;
* normalización de partidos;
* parseo de fechas;
* parseo de valores especiales;
* generación de `poll_key_strict`;
* generación de `poll_signature`;
* generación de `row_hash`;
* detección de cambio cuando cambia un porcentaje;
* detección de cambio cuando cambian fechas de campo;
* detección de cambio cuando cambia la muestra;
* no detección de cambio cuando la fila es idéntica;
* detección de caso ambiguo cuando hay dos encuestas parecidas;
* marcado como `manual_review` cuando la confianza del matching sea baja.

Añade al menos un fixture HTML o una tabla simulada basada en la estructura de Wikipedia para que los tests no dependan siempre de la web en vivo.

## Criterio de finalización

El MVP estará terminado cuando:

1. Se pueda crear el esquema de PostgreSQL desde `sql/001_schema.sql`.
2. Se pueda ejecutar `Rscript scripts/run_scraper.R`.
3. El scraper detecte la última revisión de la página de Wikipedia.
4. El scraper inserte encuestas nuevas en `polls` y `poll_results`.
5. Una segunda ejecución sobre la misma revisión no duplique datos.
6. Si cambia una encuesta ya existente, se actualice y se cree una entrada en `poll_versions`.
7. Si cambian las fechas de campo de una encuesta ya existente, el sistema pueda detectarla como probable corrección y no necesariamente como encuesta nueva.
8. Si hay ambigüedad, el sistema marque la fila como `manual_review`.
9. El workflow de GitHub Actions esté preparado para ejecutarse dos veces al día.
10. El README explique claramente cómo desplegar y operar el sistema.

# Entity Relationship

## Explicacion textual

`elections` define las elecciones disponibles. Cada `wiki_pages` pertenece a una eleccion mediante `election_key` y representa una pagina Wikipedia configurada para scraping.

`polls` es la entidad central. Cada encuesta pertenece a una `elections` por `election_id`, a una `pollsters` por `pollster_id`, y a una pagina fuente por `wiki_page`. Sus resultados se almacenan en `poll_results`, una fila por partido. `parties` cataloga nombres, colores y orden de visualizacion para claves de partido conocidas.

`wiki_page_revisions` conserva snapshots de revisiones Wikipedia y permite saber si una revision ya fue procesada correctamente. `poll_versions` conserva payloads historicos de encuestas cuando cambian. `poll_identity_events` registra decisiones de matching, correcciones, ambiguedades y desactivaciones. `scraper_runs` audita cada ejecucion.

Algunas relaciones son logicas pero no estan reforzadas por FK: `wiki_revision_id` y `revision_id` son IDs de MediaWiki, no claves primarias de `wiki_page_revisions`.

## Diagrama Mermaid ER

```mermaid
erDiagram
    elections ||--o{ wiki_pages : configures
    elections ||--o{ polls : has
    pollsters ||--o{ polls : conducts
    wiki_pages ||--o{ wiki_page_revisions : has_revisions
    wiki_pages ||--o{ polls : sources
    wiki_pages ||--o{ scraper_runs : scraped_by
    polls ||--o{ poll_results : contains
    parties ||--o{ poll_results : describes
    polls ||--o{ poll_versions : has_versions
    polls ||--o{ poll_identity_events : has_events

    elections {
        bigint id PK
        text election_key UK
        text election_type
        text territory_code
        text election_name
        date election_date
    }

    pollsters {
        bigint id PK
        text pollster_name
        text pollster_key UK
    }

    parties {
        text party_key PK
        text party_name
        text short_name
        text territory_code
        text color_hex
        integer display_order
        boolean is_active
    }

    polls {
        bigint id PK
        text poll_key_strict UK
        bigint election_id FK
        bigint pollster_id FK
        text media
        date fieldwork_start
        date fieldwork_end
        date publication_date
        text source_url
        text source_title
        jsonb source_reference_ids
        jsonb source_metadata
        integer sample_size
        numeric lead
        text identity_status
        boolean is_active
    }

    poll_results {
        bigint id PK
        bigint poll_id FK
        text party_key
        text party_raw
        numeric vote_share
        integer seats_min
        integer seats_max
    }

    wiki_pages {
        bigint id PK
        text page_key UK
        text page_title
        text url
        text election_key FK
        boolean is_active
    }

    wiki_page_revisions {
        bigint id PK
        text page_key FK
        bigint revision_id
        timestamptz revision_timestamp
        text parse_status
    }

    poll_versions {
        bigint id PK
        bigint poll_id FK
        bigint wiki_revision_id
        text row_hash
        jsonb payload_json
        timestamptz valid_from
    }

    poll_identity_events {
        bigint id PK
        bigint poll_id FK
        bigint wiki_revision_id
        text event_type
        numeric confidence
        jsonb reasons
    }

    scraper_runs {
        bigint id PK
        timestamptz started_at
        timestamptz finished_at
        text status
        text page_key FK
        bigint revision_id
    }
```

# Sample Data

Los ejemplos son simulados pero respetan nombres de columnas y tipos del esquema actual.

## Ejemplo de fila de `polls`

```json
{
  "id": 101,
  "poll_key_strict": "congreso_espana_2026__40db__prisa__2026-05-28__2026-06-01__2000",
  "poll_signature": "congreso_espana_2026__40db__prisa__2000__2026-06-02",
  "election_id": 1,
  "pollster_id": 12,
  "media": "Prisa",
  "fieldwork_start": "2026-05-28",
  "fieldwork_end": "2026-06-01",
  "publication_date": "2026-06-02",
  "sample_size": 2000,
  "turnout": null,
  "lead": 4.5,
  "wiki_page": "next_spanish_general_election",
  "wiki_revision_id": 123456789,
  "source_url": "https://example.com/poll",
  "source_title": "40dB poll headline",
  "source_reference_ids": ["cite_note-1"],
  "source_metadata": {
    "cite_note-1": {
      "reference_id": "cite_note-1",
      "url": "https://example.com/poll",
      "title": "40dB poll headline",
      "publisher": "Prisa",
      "publication_date": "2026-06-02",
      "publication_date_raw": "2026-06-02",
      "reference_text": "^ 40dB poll headline. Prisa. 2 June 2026."
    }
  },
  "row_hash": "9f8a7b6c5d4e3f20112233445566778899aabbccddeeff001122334455667788",
  "identity_status": "exact",
  "identity_confidence": 1.0,
  "first_seen_at": "2026-07-01T08:00:00Z",
  "last_seen_at": "2026-07-01T08:00:00Z",
  "updated_at": "2026-07-01T08:00:00Z",
  "is_active": true
}
```

## Varias filas de `poll_results`

```json
[
  { "id": 1001, "poll_id": 101, "party_key": "pp", "party_raw": "PP", "vote_share": 32.4, "seats_min": null, "seats_max": null, "raw_value": "32.4" },
  { "id": 1002, "poll_id": 101, "party_key": "psoe", "party_raw": "PSOE", "vote_share": 27.9, "seats_min": null, "seats_max": null, "raw_value": "27.9" },
  { "id": 1003, "poll_id": 101, "party_key": "vox", "party_raw": "Vox", "vote_share": 15.1, "seats_min": null, "seats_max": null, "raw_value": "15.1" },
  { "id": 1004, "poll_id": 101, "party_key": "sumar", "party_raw": "Sumar", "vote_share": 10.6, "seats_min": null, "seats_max": null, "raw_value": "10.6" }
]
```

## Ejemplo de fila de `parties`

```json
{
  "party_key": "pp",
  "party_name": "Partido Popular",
  "short_name": "PP",
  "territory_code": "ES",
  "color_hex": "#1d84ce",
  "display_order": 20,
  "is_active": true
}
```

## Respuesta esperada para `/api/v1/polls`

```json
{
  "items": [
    {
      "id": 101,
      "election_key": "congreso_espana_2026",
      "pollster_key": "40db",
      "pollster_name": "40dB",
      "media": "Prisa",
      "fieldwork_start": "2026-05-28",
      "fieldwork_end": "2026-06-01",
      "publication_date": "2026-06-02",
      "sample_size": 2000,
      "turnout": null,
      "lead": 4.5,
      "source_url": "https://example.com/poll",
      "source_title": "40dB poll headline",
      "identity_status": "exact",
      "first_seen_at": "2026-07-01T08:00:00Z",
      "is_active": true
    }
  ],
  "limit": 100,
  "offset": 0,
  "total": 1
}
```

## Respuesta esperada para `/api/v1/polls/{poll_id}`

```json
{
  "id": 101,
  "election_key": "congreso_espana_2026",
  "election_name": "Next Spanish general election",
  "territory_code": "ES",
  "pollster_key": "40db",
  "pollster_name": "40dB",
  "media": "Prisa",
  "fieldwork_start": "2026-05-28",
  "fieldwork_end": "2026-06-01",
  "publication_date": "2026-06-02",
  "sample_size": 2000,
  "turnout": null,
  "lead": 4.5,
  "source_url": "https://example.com/poll",
  "source_title": "40dB poll headline",
  "identity_status": "exact",
  "is_active": true,
  "results": [
    { "party_key": "pp", "party_raw": "PP", "party_name": "Partido Popular", "short_name": "PP", "color_hex": "#1d84ce", "vote_share": 32.4, "seats_min": null, "seats_max": null },
    { "party_key": "psoe", "party_raw": "PSOE", "party_name": "Partido Socialista Obrero Espanol", "short_name": "PSOE", "color_hex": "#e30613", "vote_share": 27.9, "seats_min": null, "seats_max": null },
    { "party_key": "vox", "party_raw": "Vox", "party_name": "Vox", "short_name": "Vox", "color_hex": "#63be21", "vote_share": 15.1, "seats_min": null, "seats_max": null },
    { "party_key": "sumar", "party_raw": "Sumar", "party_name": "Sumar", "short_name": "Sumar", "color_hex": "#e51b7e", "vote_share": 10.6, "seats_min": null, "seats_max": null }
  ]
}
```

## Respuesta esperada para `/api/v1/results`

```json
{
  "items": [
    {
      "poll_id": 101,
      "date": "2026-06-01",
      "party_key": "pp",
      "party_raw": "PP",
      "party_name": "Partido Popular",
      "short_name": "PP",
      "color_hex": "#1d84ce",
      "vote_share": 32.4,
      "seats_min": null,
      "seats_max": null,
      "pollster_key": "40db",
      "pollster_name": "40dB",
      "media": "Prisa",
      "sample_size": 2000
    },
    {
      "poll_id": 101,
      "date": "2026-06-01",
      "party_key": "psoe",
      "party_raw": "PSOE",
      "party_name": "Partido Socialista Obrero Espanol",
      "short_name": "PSOE",
      "color_hex": "#e30613",
      "vote_share": 27.9,
      "seats_min": null,
      "seats_max": null,
      "pollster_key": "40db",
      "pollster_name": "40dB",
      "media": "Prisa",
      "sample_size": 2000
    }
  ],
  "limit": 100,
  "offset": 0,
  "total": 2
}
```

## Respuesta esperada para `/api/v1/timeseries`

```json
{
  "items": [
    { "date": "2026-06-01", "poll_id": 101, "party_key": "pp", "vote_share": 32.4, "pollster_key": "40db", "media": "Prisa" },
    { "date": "2026-06-01", "poll_id": 101, "party_key": "psoe", "vote_share": 27.9, "pollster_key": "40db", "media": "Prisa" }
  ],
  "limit": 100,
  "offset": 0,
  "total": 2
}
```

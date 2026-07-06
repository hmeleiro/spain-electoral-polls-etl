import type { ReviewDetail, ReviewQueueItem } from "./types";

export const mockQueue: ReviewQueueItem[] = [
  {
    poll_id: 202,
    election_key: "congreso_espana_2027",
    territory_code: "ES",
    pollster_key: "40db",
    pollster_name: "40dB",
    media: "El Pais",
    fieldwork_start: "2026-06-01",
    fieldwork_end: "2026-06-05",
    publication_date: "2026-06-06",
    sample_size: 1200,
    source_url: "https://example.com/poll-40db",
    source_title: "Barometro electoral de junio",
    wiki_page: "next_spanish_general_election",
    identity_status: "manual_review",
    identity_confidence: 0.76,
    is_active: true,
    result_count: 8,
    vote_share_sum: 92.4,
    anomaly_count: 2,
    error_count: 0,
    warning_count: 2,
    review_status: "pending",
    review_priority: 80,
    latest_identity_event_type: "manual_review",
    latest_identity_event_reasons: ["ambiguous_or_low_confidence", "same_pollster", "close_publication_date"],
    anomalies: [
      { severity: "warning", code: "manual_review_status", message: "La encuesta esta marcada para revision manual." },
      { severity: "warning", code: "low_identity_confidence", message: "La confianza del matching esta por debajo de 0.85." }
    ]
  },
  {
    poll_id: 211,
    election_key: "congreso_espana_2027",
    territory_code: "ES",
    pollster_key: "sigma_dos",
    pollster_name: "Sigma Dos",
    media: "El Mundo",
    fieldwork_start: "2026-06-12",
    fieldwork_end: "2026-06-16",
    publication_date: "2026-06-17",
    sample_size: null,
    source_url: null,
    source_title: "Sondeo electoral",
    wiki_page: "next_spanish_general_election",
    identity_status: "manual_review",
    identity_confidence: 0.59,
    is_active: true,
    result_count: 7,
    vote_share_sum: 87.8,
    anomaly_count: 3,
    error_count: 1,
    warning_count: 2,
    review_status: "needs_fix",
    review_priority: 100,
    latest_identity_event_type: "manual_review",
    latest_identity_event_reasons: ["no_probable_candidates"],
    anomalies: [
      { severity: "error", code: "missing_sample_size", message: "Falta el tamano muestral." },
      { severity: "warning", code: "missing_source_url", message: "No hay URL externa de fuente; revisar metadatos de referencia." },
      { severity: "warning", code: "vote_share_sum_low", message: "La suma de porcentajes esta por debajo de 75." }
    ]
  },
  {
    poll_id: 198,
    election_key: "congreso_espana_2027",
    territory_code: "ES",
    pollster_key: "gad3",
    pollster_name: "GAD3",
    media: "ABC",
    fieldwork_start: "2026-05-20",
    fieldwork_end: "2026-05-23",
    publication_date: "2026-05-24",
    sample_size: 1004,
    source_url: "https://example.com/gad3",
    source_title: "Encuesta nacional",
    wiki_page: "next_spanish_general_election",
    identity_status: "manual_review",
    identity_confidence: 0.82,
    is_active: false,
    result_count: 8,
    vote_share_sum: 94.1,
    anomaly_count: 2,
    error_count: 0,
    warning_count: 2,
    review_status: "rejected",
    review_priority: 10,
    latest_identity_event_type: "manual_review_rejected",
    latest_review_action: "rejected",
    latest_reviewer: "admin@example.com",
    latest_review_at: "2026-07-02T15:40:00Z",
    anomalies: [
      { severity: "warning", code: "inactive_poll", message: "La encuesta esta inactiva o ya no aparece en la fuente actual." },
      { severity: "warning", code: "manual_review_status", message: "La encuesta esta marcada para revision manual." }
    ]
  }
];

export const mockDetails: Record<number, ReviewDetail> = {
  202: {
    ...mockQueue[0],
    election_type: "general",
    election_name: "Next Spanish general election",
    wiki_page_title: "Opinion polling for the next Spanish general election",
    wiki_page_url: "https://en.wikipedia.org/wiki/Opinion_polling_for_the_next_Spanish_general_election",
    wiki_revision_id: 123456789,
    turnout: null,
    lead: 4.5,
    source_reference_ids: ["cite_note-1"],
    source_metadata: {
      "cite_note-1": {
        publisher: "El Pais",
        publication_date: "2026-06-06",
        reference_text: "40dB poll headline. El Pais. 6 June 2026."
      }
    },
    first_seen_at: "2026-07-02T08:00:00Z",
    last_seen_at: "2026-07-02T08:00:00Z",
    updated_at: "2026-07-02T08:00:00Z",
    latest_identity_event_confidence: 0.76,
    latest_identity_event_at: "2026-07-02T08:00:00Z",
    latest_payload_json: {
      pollster_key: "40db",
      media: "El Pais",
      sample_size: 1200
    },
    latest_payload_at: "2026-07-02T08:00:00Z",
    match_candidates: [
      {
        candidate_poll_id: 184,
        rank: 1,
        confidence: 0.82,
        reasons: ["same_election", "same_pollster", "same_media", "close_publication_date", "similar_vote_results"],
        pollster_key: "40db",
        pollster_name: "40dB",
        media: "El Pais",
        fieldwork_start: "2026-05-28",
        fieldwork_end: "2026-06-02",
        publication_date: "2026-06-03",
        sample_size: 1200,
        source_url: "https://example.com/previous-40db",
        source_title: "Barometro electoral anterior",
        identity_status: "probable_match",
        vote_share_sum: 92.1,
        results: [
          { party_key: "pp", party_raw: "PP", short_name: "PP", vote_share: 32.8, raw_value: "32.8" },
          { party_key: "psoe", party_raw: "PSOE", short_name: "PSOE", vote_share: 28.9, raw_value: "28.9" },
          { party_key: "vox", party_raw: "Vox", short_name: "Vox", vote_share: 14.1, raw_value: "14.1" },
          { party_key: "sumar", party_raw: "Sumar", short_name: "Sumar", vote_share: 10.2, raw_value: "10.2" }
        ]
      },
      {
        candidate_poll_id: 177,
        rank: 2,
        confidence: 0.77,
        reasons: ["same_election", "same_pollster", "same_media", "close_fieldwork_dates"],
        pollster_key: "40db",
        pollster_name: "40dB",
        media: "El Pais",
        fieldwork_start: "2026-05-20",
        fieldwork_end: "2026-05-24",
        publication_date: "2026-05-25",
        sample_size: 1100,
        source_url: "https://example.com/older-40db",
        source_title: "Sondeo de mayo",
        identity_status: "new_poll",
        vote_share_sum: 91.8,
        results: [
          { party_key: "pp", party_raw: "PP", short_name: "PP", vote_share: 31.9, raw_value: "31.9" },
          { party_key: "psoe", party_raw: "PSOE", short_name: "PSOE", vote_share: 29.4, raw_value: "29.4" },
          { party_key: "vox", party_raw: "Vox", short_name: "Vox", vote_share: 13.7, raw_value: "13.7" },
          { party_key: "sumar", party_raw: "Sumar", short_name: "Sumar", vote_share: 10.7, raw_value: "10.7" }
        ]
      }
    ],
    results: [
      { poll_id: 202, party_key: "pp", party_raw: "PP", party_name: "Partido Popular", short_name: "PP", color_hex: "#1d84ce", display_order: 20, is_unknown_party: false, vote_share: 33.1, raw_value: "33.1", recent_average_vote_share: 31.6, delta_from_recent_average: 1.5 },
      { poll_id: 202, party_key: "psoe", party_raw: "PSOE", party_name: "Partido Socialista Obrero Espanol", short_name: "PSOE", color_hex: "#e30613", display_order: 10, is_unknown_party: false, vote_share: 28.6, raw_value: "28.6", recent_average_vote_share: 29.8, delta_from_recent_average: -1.2 },
      { poll_id: 202, party_key: "vox", party_raw: "Vox", party_name: "Vox", short_name: "Vox", color_hex: "#63be21", display_order: 30, is_unknown_party: false, vote_share: 14.2, raw_value: "14.2", recent_average_vote_share: 13.7, delta_from_recent_average: 0.5 },
      { poll_id: 202, party_key: "sumar", party_raw: "Sumar", party_name: "Sumar", short_name: "Sumar", color_hex: "#e51b7e", display_order: 40, is_unknown_party: false, vote_share: 10.5, raw_value: "10.5", recent_average_vote_share: 10.1, delta_from_recent_average: 0.4 },
      { poll_id: 202, party_key: "others", party_raw: "Others", party_name: "Others", short_name: "Otros", color_hex: "#8f8f8f", display_order: 999, is_unknown_party: false, vote_share: 6.0, raw_value: "6.0", recent_average_vote_share: 6.4, delta_from_recent_average: -0.4 }
    ]
  },
  211: {
    ...mockQueue[1],
    election_type: "general",
    election_name: "Next Spanish general election",
    wiki_page_title: "Opinion polling for the next Spanish general election",
    wiki_page_url: "https://en.wikipedia.org/wiki/Opinion_polling_for_the_next_Spanish_general_election",
    wiki_revision_id: 123456790,
    turnout: null,
    lead: 2.1,
    source_reference_ids: ["cite_note-8"],
    source_metadata: {
      "cite_note-8": {
        publisher: "El Mundo",
        reference_text: "Sondeo electoral. El Mundo."
      }
    },
    first_seen_at: "2026-07-02T08:10:00Z",
    last_seen_at: "2026-07-02T08:10:00Z",
    updated_at: "2026-07-02T08:10:00Z",
    latest_identity_event_confidence: 0.59,
    latest_identity_event_at: "2026-07-02T08:10:00Z",
    latest_payload_json: {
      pollster_key: "sigma_dos",
      media: "El Mundo"
    },
    latest_payload_at: "2026-07-02T08:10:00Z",
    latest_review_notes: "Falta comprobar la fuente original.",
    match_candidates: [],
    results: [
      { poll_id: 211, party_key: "pp", party_raw: "PP", party_name: "Partido Popular", short_name: "PP", color_hex: "#1d84ce", display_order: 20, is_unknown_party: false, vote_share: 31.4, raw_value: "31.4", recent_average_vote_share: 31.6, delta_from_recent_average: -0.2 },
      { poll_id: 211, party_key: "psoe", party_raw: "PSOE", party_name: "Partido Socialista Obrero Espanol", short_name: "PSOE", color_hex: "#e30613", display_order: 10, is_unknown_party: false, vote_share: 29.3, raw_value: "29.3", recent_average_vote_share: 29.8, delta_from_recent_average: -0.5 },
      { poll_id: 211, party_key: "vox", party_raw: "Vox", party_name: "Vox", short_name: "Vox", color_hex: "#63be21", display_order: 30, is_unknown_party: false, vote_share: 13.8, raw_value: "13.8", recent_average_vote_share: 13.7, delta_from_recent_average: 0.1 },
      { poll_id: 211, party_key: "nuevo_partido", party_raw: "Nuevo Partido", party_name: "Nuevo Partido", short_name: "Nuevo", color_hex: null, display_order: null, is_unknown_party: true, vote_share: 2.4, raw_value: "2.4", recent_average_vote_share: null, delta_from_recent_average: null }
    ]
  },
  198: {
    ...mockQueue[2],
    election_type: "general",
    election_name: "Next Spanish general election",
    wiki_page_title: "Opinion polling for the next Spanish general election",
    wiki_page_url: "https://en.wikipedia.org/wiki/Opinion_polling_for_the_next_Spanish_general_election",
    wiki_revision_id: 123456750,
    turnout: null,
    lead: 4.4,
    first_seen_at: "2026-07-02T07:50:00Z",
    last_seen_at: "2026-07-02T07:50:00Z",
    updated_at: "2026-07-02T15:40:00Z",
    match_candidates: [
      {
        candidate_poll_id: 192,
        rank: 1,
        confidence: 0.79,
        reasons: ["same_election", "same_pollster", "same_media", "close_publication_date"],
        pollster_key: "gad3",
        pollster_name: "GAD3",
        media: "ABC",
        fieldwork_start: "2026-05-18",
        fieldwork_end: "2026-05-22",
        publication_date: "2026-05-23",
        sample_size: 1000,
        source_url: "https://example.com/gad3-previous",
        source_title: "Encuesta nacional anterior",
        identity_status: "new_poll",
        vote_share_sum: 93.8,
        results: [
          { party_key: "pp", party_raw: "PP", short_name: "PP", vote_share: 32.5 },
          { party_key: "psoe", party_raw: "PSOE", short_name: "PSOE", vote_share: 28.1 },
          { party_key: "vox", party_raw: "Vox", short_name: "Vox", vote_share: 14.8 }
        ]
      }
    ],
    results: [
      { poll_id: 198, party_key: "pp", party_raw: "PP", party_name: "Partido Popular", short_name: "PP", color_hex: "#1d84ce", display_order: 20, is_unknown_party: false, vote_share: 32.7, raw_value: "32.7", recent_average_vote_share: 31.6, delta_from_recent_average: 1.1 },
      { poll_id: 198, party_key: "psoe", party_raw: "PSOE", party_name: "Partido Socialista Obrero Espanol", short_name: "PSOE", color_hex: "#e30613", display_order: 10, is_unknown_party: false, vote_share: 28.3, raw_value: "28.3", recent_average_vote_share: 29.8, delta_from_recent_average: -1.5 },
      { poll_id: 198, party_key: "vox", party_raw: "Vox", party_name: "Vox", short_name: "Vox", color_hex: "#63be21", display_order: 30, is_unknown_party: false, vote_share: 14.6, raw_value: "14.6", recent_average_vote_share: 13.7, delta_from_recent_average: 0.9 }
    ]
  }
};

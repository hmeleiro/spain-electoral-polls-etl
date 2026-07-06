export type ReviewStatus = "pending" | "needs_fix" | "reviewed" | "rejected";

export type ReviewAction =
  | "approved_new_poll"
  | "approved_match"
  | "rejected"
  | "needs_fix"
  | "comment";

export type Severity = "error" | "warning" | "info";

export interface ReviewAnomaly {
  severity: Severity;
  code: string;
  message: string;
}

export interface ReviewQueueItem {
  poll_id: number;
  election_key: string;
  territory_code: string;
  pollster_key?: string;
  pollster_name: string;
  media?: string | null;
  fieldwork_start?: string | null;
  fieldwork_end?: string | null;
  publication_date?: string | null;
  sample_size?: number | null;
  source_url?: string | null;
  source_title?: string | null;
  wiki_page?: string;
  identity_status: string;
  identity_confidence?: number | null;
  is_active: boolean;
  result_count: number;
  vote_share_sum?: number | null;
  anomaly_count: number;
  error_count: number;
  warning_count: number;
  anomalies: ReviewAnomaly[];
  latest_identity_event_type?: string | null;
  latest_identity_event_reasons?: string[] | null;
  latest_review_action?: ReviewAction | null;
  latest_reviewer?: string | null;
  latest_review_at?: string | null;
  review_status: ReviewStatus;
  review_priority: number;
}

export interface ReviewResult {
  poll_id: number;
  party_key: string;
  party_raw?: string | null;
  party_name?: string | null;
  short_name: string;
  color_hex?: string | null;
  display_order?: number | null;
  is_unknown_party: boolean;
  vote_share?: number | null;
  seats_min?: number | null;
  seats_max?: number | null;
  raw_value?: string | null;
  recent_average_vote_share?: number | null;
  delta_from_recent_average?: number | null;
}

export interface ReviewMatchCandidateResult {
  party_key: string;
  party_raw?: string | null;
  short_name?: string | null;
  vote_share?: number | null;
  seats_min?: number | null;
  seats_max?: number | null;
  raw_value?: string | null;
}

export interface ReviewMatchCandidate {
  candidate_poll_id: number;
  rank: number;
  confidence?: number | null;
  reasons: string[];
  pollster_key?: string | null;
  pollster_name?: string | null;
  media?: string | null;
  fieldwork_start?: string | null;
  fieldwork_end?: string | null;
  publication_date?: string | null;
  sample_size?: number | null;
  source_url?: string | null;
  source_title?: string | null;
  identity_status?: string | null;
  vote_share_sum?: number | null;
  results: ReviewMatchCandidateResult[];
}

export interface ReviewDetail extends ReviewQueueItem {
  election_type?: string;
  election_name?: string;
  wiki_page_title?: string | null;
  wiki_page_url?: string | null;
  wiki_revision_id?: number | null;
  turnout?: number | null;
  lead?: number | null;
  source_reference_ids?: unknown[];
  source_metadata?: Record<string, unknown>;
  first_seen_at?: string;
  last_seen_at?: string;
  updated_at?: string;
  results: ReviewResult[];
  match_candidates: ReviewMatchCandidate[];
  latest_identity_event_confidence?: number | null;
  latest_identity_event_at?: string | null;
  latest_payload_json?: Record<string, unknown> | null;
  latest_payload_at?: string | null;
  latest_review_notes?: string | null;
}

export interface PaginatedResponse<T> {
  items: T[];
  limit: number;
  offset: number;
  total: number;
}

export interface ReviewActionPayload {
  action: ReviewAction;
  reviewer?: string;
  notes?: string;
  corrected_payload?: Record<string, unknown>;
}

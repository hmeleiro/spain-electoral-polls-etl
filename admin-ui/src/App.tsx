import {
  AlertTriangle,
  Check,
  ChevronRight,
  CircleSlash,
  ClipboardCheck,
  ExternalLink,
  FileQuestion,
  Filter,
  Flag,
  MessageSquare,
  Network,
  RefreshCw,
  Search
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { fetchReviewDetail, fetchReviewQueue, submitReviewAction } from "./api";
import type { ReviewAction, ReviewAnomaly, ReviewDetail, ReviewMatchCandidate, ReviewQueueItem, ReviewResult, ReviewStatus } from "./types";

const statusLabels: Record<ReviewStatus | "all", string> = {
  all: "Todas",
  pending: "Pendientes",
  needs_fix: "A corregir",
  reviewed: "Revisadas",
  rejected: "Descartadas"
};

const actionLabels: Record<ReviewAction, string> = {
  approved_new_poll: "Aprobar nueva",
  approved_match: "Aprobar match",
  rejected: "Descartar",
  needs_fix: "Marcar fix",
  comment: "Comentar"
};

type BulkReviewAction = Exclude<ReviewAction, "approved_match">;

function formatDate(value?: string | null) {
  if (!value) return "Sin fecha";
  return new Intl.DateTimeFormat("es-ES", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value));
}

function formatNumber(value?: number | null, suffix = "") {
  if (value === null || value === undefined || Number.isNaN(value)) return "-";
  return `${new Intl.NumberFormat("es-ES", { maximumFractionDigits: 1 }).format(value)}${suffix}`;
}

function severityIcon(severity: ReviewAnomaly["severity"]) {
  if (severity === "error") return <AlertTriangle size={14} />;
  if (severity === "warning") return <Flag size={14} />;
  return <FileQuestion size={14} />;
}

function statusClass(status: ReviewStatus) {
  return `status status-${status.replace("_", "-")}`;
}

function queueItemMatchesQuery(item: ReviewQueueItem, query: string) {
  const normalizedQuery = query.trim().toLowerCase();
  if (!normalizedQuery) return true;

  const haystack = [
    item.poll_id,
    item.pollster_name,
    item.media,
    item.election_key,
    item.source_title,
    item.anomalies.map((anomaly) => anomaly.code).join(" ")
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  return haystack.includes(normalizedQuery);
}

function App() {
  const [status, setStatus] = useState<ReviewStatus | "all">("all");
  const [query, setQuery] = useState("");
  const [queue, setQueue] = useState<ReviewQueueItem[]>([]);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [detail, setDetail] = useState<ReviewDetail | null>(null);
  const [loadingQueue, setLoadingQueue] = useState(true);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [submittingAction, setSubmittingAction] = useState<ReviewAction | null>(null);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [bulkNotes, setBulkNotes] = useState("");
  const [submittingBulkAction, setSubmittingBulkAction] = useState<BulkReviewAction | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [notes, setNotes] = useState("");

  useEffect(() => {
    let active = true;
    setLoadingQueue(true);
    fetchReviewQueue(status)
      .then((response) => {
        if (!active) return;
        const responseIds = new Set(response.items.map((item) => item.poll_id));
        setQueue(response.items);
        setSelectedIds((current) => new Set([...current].filter((pollId) => responseIds.has(pollId))));
        setSelectedId((current) => (current && responseIds.has(current) ? current : response.items[0]?.poll_id ?? null));
      })
      .finally(() => {
        if (active) setLoadingQueue(false);
      });
    return () => {
      active = false;
    };
  }, [status]);

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      return;
    }

    let active = true;
    setLoadingDetail(true);
    fetchReviewDetail(selectedId)
      .then((nextDetail) => {
        if (!active) return;
        setDetail(nextDetail);
        setNotes(nextDetail.latest_review_notes ?? "");
      })
      .finally(() => {
        if (active) setLoadingDetail(false);
      });
    return () => {
      active = false;
    };
  }, [selectedId]);

  const filteredQueue = useMemo(() => {
    return queue.filter((item) => queueItemMatchesQuery(item, query));
  }, [queue, query]);

  const selectedVisibleCount = useMemo(() => {
    return filteredQueue.filter((item) => selectedIds.has(item.poll_id)).length;
  }, [filteredQueue, selectedIds]);

  const allVisibleSelected = filteredQueue.length > 0 && selectedVisibleCount === filteredQueue.length;

  async function refreshQueueAfterAction() {
    const refreshedQueue = await fetchReviewQueue(status);
    const nextSelection = refreshedQueue.items.find((item) => queueItemMatchesQuery(item, query))?.poll_id ?? null;
    setQueue(refreshedQueue.items);
    setDetail(null);
    if (!nextSelection) {
      setNotes("");
      setSelectedId(null);
    } else if (nextSelection === selectedId) {
      setLoadingDetail(true);
      try {
        const nextDetail = await fetchReviewDetail(nextSelection);
        setDetail(nextDetail);
        setNotes(nextDetail.latest_review_notes ?? "");
      } finally {
        setLoadingDetail(false);
      }
    } else {
      setSelectedId(nextSelection);
    }
  }

  function toggleSelectedId(pollId: number) {
    setSelectedIds((current) => {
      const next = new Set(current);
      if (next.has(pollId)) {
        next.delete(pollId);
      } else {
        next.add(pollId);
      }
      return next;
    });
  }

  function toggleVisibleSelection() {
    setSelectedIds((current) => {
      const next = new Set(current);
      if (allVisibleSelected) {
        filteredQueue.forEach((item) => next.delete(item.poll_id));
      } else {
        filteredQueue.forEach((item) => next.add(item.poll_id));
      }
      return next;
    });
  }

  async function handleRefreshQueue() {
    setActionError(null);
    const response = await fetchReviewQueue(status);
    const responseIds = new Set(response.items.map((item) => item.poll_id));
    setQueue(response.items);
    setSelectedIds((current) => new Set([...current].filter((pollId) => responseIds.has(pollId))));
    setSelectedId((current) => (current && responseIds.has(current) ? current : response.items[0]?.poll_id ?? null));
  }

  async function handleAction(action: ReviewAction) {
    if (!detail) return;
    setSubmittingAction(action);
    setActionError(null);
    try {
      await submitReviewAction(detail.poll_id, {
        action,
        reviewer: "admin@example.com",
        notes
      });
      setSelectedIds((current) => {
        const next = new Set(current);
        next.delete(detail.poll_id);
        return next;
      });
      await refreshQueueAfterAction();
    } catch {
      setActionError(`No se pudo registrar la acción para la encuesta #${detail.poll_id}.`);
    } finally {
      setSubmittingAction(null);
    }
  }

  async function handleBulkAction(action: BulkReviewAction) {
    const pollIds = [...selectedIds];
    if (pollIds.length === 0) return;

    setSubmittingBulkAction(action);
    setActionError(null);
    try {
      const failedPollIds: number[] = [];

      for (const pollId of pollIds) {
        try {
          await submitReviewAction(pollId, {
            action,
            reviewer: "admin@example.com",
            notes: bulkNotes
          });
        } catch {
          failedPollIds.push(pollId);
        }
      }

      if (failedPollIds.length === 0) {
        setSelectedIds(new Set());
        setBulkNotes("");
      } else {
        setSelectedIds(new Set(failedPollIds));
        setActionError(`No se pudo registrar la acción en ${failedPollIds.length} de ${pollIds.length}: ${failedPollIds.join(", ")}.`);
      }

      await refreshQueueAfterAction();
    } finally {
      setSubmittingBulkAction(null);
    }
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Spain Electoral Polls</p>
          <h1>Revisión manual</h1>
        </div>
        <button className="icon-button" title="Recargar" onClick={handleRefreshQueue}>
          <RefreshCw size={18} />
        </button>
      </header>

      <section className="workspace">
        <aside className="queue-panel">
          <div className="toolbar">
            <div className="searchbox">
              <Search size={16} />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar" />
            </div>
            <div className="filter-label">
              <Filter size={15} />
              <span>{filteredQueue.length}</span>
            </div>
          </div>

          <div className="segmented" role="tablist" aria-label="Estado de revision">
            {(Object.keys(statusLabels) as Array<ReviewStatus | "all">).map((key) => (
              <button key={key} className={status === key ? "active" : ""} onClick={() => setStatus(key)}>
                {statusLabels[key]}
              </button>
            ))}
          </div>

          {actionError ? <div className="alert-panel" role="alert">{actionError}</div> : null}

          <div className="selection-toolbar">
            <label className="select-visible">
              <input type="checkbox" checked={allVisibleSelected} onChange={toggleVisibleSelection} disabled={loadingQueue || filteredQueue.length === 0} />
              <span>{allVisibleSelected ? "Visibles seleccionadas" : "Seleccionar visibles"}</span>
            </label>
            {selectedIds.size > 0 ? (
              <button className="text-button" onClick={() => setSelectedIds(new Set())} disabled={submittingBulkAction !== null}>
                Limpiar
              </button>
            ) : null}
          </div>

          {selectedIds.size > 0 ? (
            <BulkActions
              selectedCount={selectedIds.size}
              notes={bulkNotes}
              onNotesChange={setBulkNotes}
              onAction={handleBulkAction}
              submittingAction={submittingBulkAction}
            />
          ) : null}

          <div className="queue-list" aria-busy={loadingQueue}>
            {loadingQueue ? (
              <div className="empty-state">Cargando encuestas...</div>
            ) : filteredQueue.length === 0 ? (
              <div className="empty-state">No hay encuestas en este filtro.</div>
            ) : (
              filteredQueue.map((item) => (
                <div
                  key={item.poll_id}
                  className={`queue-item ${selectedId === item.poll_id ? "selected" : ""} ${selectedIds.has(item.poll_id) ? "bulk-selected" : ""}`}
                >
                  <label className="queue-select" title="Seleccionar encuesta">
                    <input
                      type="checkbox"
                      checked={selectedIds.has(item.poll_id)}
                      onChange={() => toggleSelectedId(item.poll_id)}
                      aria-label={`Seleccionar encuesta ${item.poll_id}`}
                    />
                  </label>
                  <button className="queue-item-content" onClick={() => setSelectedId(item.poll_id)}>
                    <span className="queue-item-main">
                      <span className="queue-item-title">
                        {item.pollster_name}
                        <ChevronRight size={15} />
                      </span>
                      <span className="queue-item-meta">
                        {item.media ?? "Sin medio"} · {formatDate(item.fieldwork_end)}
                      </span>
                    </span>
                    <span className="queue-item-side">
                      <span className={statusClass(item.review_status)}>{statusLabels[item.review_status]}</span>
                      <span className="risk-count">{item.error_count}E / {item.warning_count}W</span>
                    </span>
                  </button>
                </div>
              ))
            )}
          </div>
        </aside>

        <section className="detail-panel">
          {loadingDetail ? <div className="empty-state detail-empty">Cargando detalle...</div> : null}
          {!loadingDetail && detail ? (
            <>
              <DetailHeader detail={detail} />
              <div className="detail-grid">
                <section className="primary-column">
                  <AnomalyList anomalies={detail.anomalies} />
                  <ResultsTable results={detail.results} />
                </section>
                <aside className="secondary-column">
                  <MatchCandidatesBox candidates={detail.match_candidates ?? []} />
                  <SourceBox detail={detail} />
                  <MatchingBox detail={detail} />
                  <ReviewActions
                    notes={notes}
                    onNotesChange={setNotes}
                    onAction={handleAction}
                    submittingAction={submittingAction ?? submittingBulkAction}
                    topCandidateId={(detail.match_candidates ?? [])[0]?.candidate_poll_id}
                  />
                </aside>
              </div>
            </>
          ) : null}
          {!loadingDetail && !detail ? <div className="empty-state detail-empty">Selecciona una encuesta.</div> : null}
        </section>
      </section>
    </main>
  );
}

function DetailHeader({ detail }: { detail: ReviewDetail }) {
  return (
    <header className="detail-header">
      <div>
        <p className="eyebrow">{detail.election_key}</p>
        <h2>{detail.pollster_name}</h2>
        <p className="subtle">
          {detail.media ?? "Sin medio"} · Campo {formatDate(detail.fieldwork_start)} - {formatDate(detail.fieldwork_end)}
        </p>
      </div>
      <div className="metrics-strip">
        <Metric label="Muestra" value={formatNumber(detail.sample_size)} />
        <Metric label="Suma voto" value={formatNumber(detail.vote_share_sum, "%")} />
        <Metric label="Confianza" value={formatNumber((detail.identity_confidence ?? 0) * 100, "%")} />
        <Metric label="Anomalías" value={String(detail.anomaly_count)} />
      </div>
    </header>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function ResultsTable({ results }: { results: ReviewResult[] }) {
  const sortedResults = [...results].sort((a, b) => (b.vote_share ?? -Infinity) - (a.vote_share ?? -Infinity));
  const maxVote = Math.max(40, ...sortedResults.map((result) => result.vote_share ?? 0));
  return (
    <section className="section-block">
      <div className="section-heading">
        <ClipboardCheck size={18} />
        <h3>Resultados</h3>
      </div>
      <div className="results-table">
        <div className="table-row table-head">
          <span>Partido</span>
          <span>Voto</span>
          <span>Media</span>
          <span>Delta</span>
        </div>
        {sortedResults.map((result) => (
          <div className="table-row" key={result.party_key}>
            <span className="party-cell">
              <span className="party-swatch" style={{ backgroundColor: result.color_hex ?? "#9aa4b2" }} />
              <span>
                <strong>{result.short_name}</strong>
                <small>{result.is_unknown_party ? "No catalogado" : result.party_raw}</small>
              </span>
            </span>
            <span className="vote-cell">
              <span>{formatNumber(result.vote_share, "%")}</span>
              <span className="bar-track">
                <span className="bar-fill" style={{ width: `${Math.min(100, ((result.vote_share ?? 0) / maxVote) * 100)}%`, backgroundColor: result.color_hex ?? "#6b7280" }} />
              </span>
            </span>
            <span>{formatNumber(result.recent_average_vote_share, "%")}</span>
            <span className={(result.delta_from_recent_average ?? 0) >= 0 ? "delta-up" : "delta-down"}>
              {formatNumber(result.delta_from_recent_average, " pp")}
            </span>
          </div>
        ))}
      </div>
    </section>
  );
}

function AnomalyList({ anomalies }: { anomalies: ReviewAnomaly[] }) {
  return (
    <section className="section-block">
      <div className="section-heading">
        <AlertTriangle size={18} />
        <h3>Anomalías</h3>
      </div>
      <div className="anomaly-list">
        {anomalies.map((anomaly) => (
          <div className={`anomaly anomaly-${anomaly.severity}`} key={`${anomaly.severity}-${anomaly.code}`}>
            {severityIcon(anomaly.severity)}
            <div>
              <strong>{anomaly.code}</strong>
              <span>{anomaly.message}</span>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function BulkActions({
  selectedCount,
  notes,
  onNotesChange,
  onAction,
  submittingAction
}: {
  selectedCount: number;
  notes: string;
  onNotesChange: (value: string) => void;
  onAction: (action: BulkReviewAction) => void;
  submittingAction: BulkReviewAction | null;
}) {
  const actions: Array<{ action: BulkReviewAction; icon: JSX.Element; tone: string }> = [
    { action: "approved_new_poll", icon: <Check size={16} />, tone: "positive" },
    { action: "needs_fix", icon: <AlertTriangle size={16} />, tone: "warning" },
    { action: "rejected", icon: <CircleSlash size={16} />, tone: "danger" },
    { action: "comment", icon: <MessageSquare size={16} />, tone: "neutral" }
  ];

  return (
    <section className="bulk-panel">
      <div className="bulk-heading">
        <strong>{selectedCount} seleccionadas</strong>
        <span>Lote</span>
      </div>
      <textarea value={notes} onChange={(event) => onNotesChange(event.target.value)} placeholder="Notas para la selección" rows={3} />
      <div className="bulk-action-grid">
        {actions.map(({ action, icon, tone }) => (
          <button key={action} className={`action-button ${tone}`} onClick={() => onAction(action)} disabled={submittingAction !== null}>
            {submittingAction === action ? <RefreshCw size={16} className="spin" /> : icon}
            <span>{actionLabels[action]}</span>
          </button>
        ))}
      </div>
    </section>
  );
}

function ReviewActions({
  notes,
  onNotesChange,
  onAction,
  submittingAction,
  topCandidateId
}: {
  notes: string;
  onNotesChange: (value: string) => void;
  onAction: (action: ReviewAction) => void;
  submittingAction: ReviewAction | null;
  topCandidateId?: number;
}) {
  const actions: Array<{ action: ReviewAction; icon: JSX.Element; tone: string }> = [
    { action: "approved_new_poll", icon: <Check size={17} />, tone: "positive" },
    { action: "approved_match", icon: <ClipboardCheck size={17} />, tone: "positive" },
    { action: "needs_fix", icon: <AlertTriangle size={17} />, tone: "warning" },
    { action: "rejected", icon: <CircleSlash size={17} />, tone: "danger" },
    { action: "comment", icon: <MessageSquare size={17} />, tone: "neutral" }
  ];

  return (
    <section className="side-block">
      <h3>Decisión</h3>
      <textarea value={notes} onChange={(event) => onNotesChange(event.target.value)} placeholder="Notas internas" rows={5} />
      {topCandidateId ? (
        <p className="action-hint">Aprobar match acepta que corresponde a la candidata #{topCandidateId}.</p>
      ) : null}
      <div className="action-grid">
        {actions.map(({ action, icon, tone }) => (
          <button key={action} className={`action-button ${tone}`} onClick={() => onAction(action)} disabled={submittingAction !== null}>
            {submittingAction === action ? <RefreshCw size={17} className="spin" /> : icon}
            <span>{actionLabels[action]}</span>
          </button>
        ))}
      </div>
    </section>
  );
}

function MatchCandidatesBox({ candidates }: { candidates: ReviewMatchCandidate[] }) {
  const [selectedCandidateId, setSelectedCandidateId] = useState<number | null>(candidates[0]?.candidate_poll_id ?? null);
  const selectedCandidate = candidates.find((candidate) => candidate.candidate_poll_id === selectedCandidateId) ?? candidates[0];

  useEffect(() => {
    setSelectedCandidateId(candidates[0]?.candidate_poll_id ?? null);
  }, [candidates]);

  return (
    <section className="side-block">
      <div className="side-heading">
        <Network size={17} />
        <h3>Encuestas parecidas</h3>
      </div>
      {candidates.length === 0 ? (
        <div className="compact-empty">No hay candidatas registradas para esta revisión.</div>
      ) : (
        <>
          <div className="candidate-list">
            {candidates.map((candidate) => (
              <button
                key={candidate.candidate_poll_id}
                className={`candidate-card ${selectedCandidate?.candidate_poll_id === candidate.candidate_poll_id ? "active" : ""}`}
                onClick={() => setSelectedCandidateId(candidate.candidate_poll_id)}
              >
                <span>
                  <strong>#{candidate.candidate_poll_id}</strong>
                  <small>{candidate.pollster_name ?? candidate.pollster_key ?? "Sin encuestadora"}</small>
                </span>
                <span className="candidate-confidence">{formatNumber((candidate.confidence ?? 0) * 100, "%")}</span>
              </button>
            ))}
          </div>
          {selectedCandidate ? <CandidateDetail candidate={selectedCandidate} /> : null}
        </>
      )}
    </section>
  );
}

function CandidateDetail({ candidate }: { candidate: ReviewMatchCandidate }) {
  const sortedResults = [...candidate.results].sort((a, b) => (b.vote_share ?? -Infinity) - (a.vote_share ?? -Infinity));

  return (
    <div className="candidate-detail">
      <dl className="metadata-list">
        <div>
          <dt>Medio</dt>
          <dd>{candidate.media ?? "-"}</dd>
        </div>
        <div>
          <dt>Campo</dt>
          <dd>{formatDate(candidate.fieldwork_start)} - {formatDate(candidate.fieldwork_end)}</dd>
        </div>
        <div>
          <dt>Muestra</dt>
          <dd>{formatNumber(candidate.sample_size)}</dd>
        </div>
        <div>
          <dt>Suma voto</dt>
          <dd>{formatNumber(candidate.vote_share_sum, "%")}</dd>
        </div>
      </dl>
      <div className="reason-list">
        {candidate.reasons.map((reason) => (
          <span key={reason}>{reason}</span>
        ))}
      </div>
      <div className="candidate-results">
        {sortedResults.slice(0, 5).map((result) => (
          <div key={result.party_key}>
            <span>{result.short_name ?? result.party_raw ?? result.party_key}</span>
            <strong>{formatNumber(result.vote_share, "%")}</strong>
          </div>
        ))}
      </div>
    </div>
  );
}

function SourceBox({ detail }: { detail: ReviewDetail }) {
  return (
    <section className="side-block">
      <h3>Fuente</h3>
      <dl className="metadata-list">
        <div>
          <dt>Publicación</dt>
          <dd>{formatDate(detail.publication_date)}</dd>
        </div>
        <div>
          <dt>Referencia</dt>
          <dd>{detail.source_title ?? "Sin título"}</dd>
        </div>
        <div>
          <dt>Wikipedia</dt>
          <dd>{detail.wiki_page_title ?? detail.wiki_page}</dd>
        </div>
      </dl>
      <div className="source-links">
        {detail.source_url ? (
          <a href={detail.source_url} target="_blank" rel="noreferrer">
            <ExternalLink size={15} />
            Fuente
          </a>
        ) : null}
        {detail.wiki_page_url ? (
          <a href={detail.wiki_page_url} target="_blank" rel="noreferrer">
            <ExternalLink size={15} />
            Wikipedia
          </a>
        ) : null}
      </div>
    </section>
  );
}

function MatchingBox({ detail }: { detail: ReviewDetail }) {
  return (
    <section className="side-block">
      <h3>Matching</h3>
      <dl className="metadata-list">
        <div>
          <dt>Estado</dt>
          <dd>{detail.identity_status}</dd>
        </div>
        <div>
          <dt>Evento</dt>
          <dd>{detail.latest_identity_event_type ?? "-"}</dd>
        </div>
      </dl>
      <div className="reason-list">
        {(detail.latest_identity_event_reasons ?? []).map((reason) => (
          <span key={reason}>{reason}</span>
        ))}
      </div>
    </section>
  );
}

export default App;

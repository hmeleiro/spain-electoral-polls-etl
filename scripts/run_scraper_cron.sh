#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${SCRAPER_LOG_DIR:-$REPO_DIR/logs}"
LOG_FILE="$LOG_DIR/scraper-$(date +%F).log"
LOCK_FILE="${SCRAPER_LOCK_FILE:-$REPO_DIR/.scraper.lock}"
RSCRIPT_BIN="${RSCRIPT_BIN:-Rscript}"
SCRAPER_RESULT_FILE=""

timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

mkdir -p "$LOG_DIR"
cd "$REPO_DIR"

if [[ -f "$REPO_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_DIR/.env"
  set +a
fi

run_scraper() {
  SCRAPER_RESULT_FILE="$(mktemp "$LOG_DIR/scraper-result.XXXXXX")"
  export SCRAPER_RESULT_FILE

  echo "===== $(timestamp) scraper start ====="
  if "$RSCRIPT_BIN" scripts/run_scraper.R; then
    echo "===== $(timestamp) scraper end ====="
  else
    status=$?
    echo "===== $(timestamp) scraper failed: exit $status ====="
    return "$status"
  fi
}

result_value() {
  local key="$1"
  local name
  local value

  while IFS='=' read -r name value; do
    if [[ "$name" == "$key" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done < "$SCRAPER_RESULT_FILE"

  return 1
}

run_downstream_if_needed() {
  local scraper_status
  local revision_id
  local page_key
  local data_dir
  local downstream_script
  local downstream_run_id
  local downstream_status

  if [[ -z "$SCRAPER_RESULT_FILE" || ! -s "$SCRAPER_RESULT_FILE" ]]; then
    echo "===== $(timestamp) scraper failed: missing result file ====="
    return 1
  fi

  if ! scraper_status="$(result_value status)"; then
    echo "===== $(timestamp) scraper failed: missing status in result file ====="
    return 1
  fi
  if ! revision_id="$(result_value revision_id)"; then
    echo "===== $(timestamp) scraper failed: missing revision_id in result file ====="
    return 1
  fi
  if ! page_key="$(result_value page_key)"; then
    echo "===== $(timestamp) scraper failed: missing page_key in result file ====="
    return 1
  fi

  case "$scraper_status" in
    success)
      if [[ -z "${POLL_OF_POLLS_DATA_DIR:-}" ]]; then
        echo "===== $(timestamp) downstream failed: POLL_OF_POLLS_DATA_DIR is required after scraper success ====="
        return 1
      fi

      if [[ "$POLL_OF_POLLS_DATA_DIR" != /* ]]; then
        echo "===== $(timestamp) downstream failed: POLL_OF_POLLS_DATA_DIR must be an absolute path ====="
        return 1
      fi

      data_dir="${POLL_OF_POLLS_DATA_DIR%/}"
      downstream_script="$data_dir/scripts/run_pipeline_cron.sh"
      if [[ ! -f "$downstream_script" ]]; then
        echo "===== $(timestamp) downstream failed: script not found at $downstream_script ====="
        return 1
      fi

      downstream_run_id="wiki-${revision_id}-$(date -u +"%Y%m%dT%H%M%SZ")"
      echo "===== $(timestamp) downstream start: page_key=$page_key revision_id=$revision_id run_id=$downstream_run_id ====="
      if (
        cd "$data_dir"
        RUN_ID="$downstream_run_id" bash "$downstream_script"
      ); then
        echo "===== $(timestamp) downstream end: run_id=$downstream_run_id ====="
      else
        downstream_status=$?
        echo "===== $(timestamp) downstream failed: run_id=$downstream_run_id exit=$downstream_status ====="
        return "$downstream_status"
      fi
      ;;
    no_change)
      echo "===== $(timestamp) downstream skipped: scraper status=no_change page_key=$page_key revision_id=$revision_id ====="
      ;;
    *)
      echo "===== $(timestamp) downstream failed: unexpected scraper status=$scraper_status ====="
      return 1
      ;;
  esac
}

run_pipeline() {
  run_scraper
  run_downstream_if_needed
}

{
  trap 'if [[ -n "${SCRAPER_RESULT_FILE:-}" ]]; then rm -f "$SCRAPER_RESULT_FILE"; fi' EXIT

  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      echo "===== $(timestamp) scraper skipped: already running ====="
      exit 0
    fi
    run_pipeline
  else
    echo "===== $(timestamp) scraper warning: flock not found; running without lock ====="
    run_pipeline
  fi
} >> "$LOG_FILE" 2>&1

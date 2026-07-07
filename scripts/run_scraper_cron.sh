#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${SCRAPER_LOG_DIR:-$REPO_DIR/logs}"
LOG_FILE="$LOG_DIR/scraper-$(date +%F).log"
LOCK_FILE="${SCRAPER_LOCK_FILE:-$REPO_DIR/.scraper.lock}"
RSCRIPT_BIN="${RSCRIPT_BIN:-Rscript}"

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
  echo "===== $(timestamp) scraper start ====="
  if "$RSCRIPT_BIN" scripts/run_scraper.R; then
    echo "===== $(timestamp) scraper end ====="
  else
    status=$?
    echo "===== $(timestamp) scraper failed: exit $status ====="
    return "$status"
  fi
}

{
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      echo "===== $(timestamp) scraper skipped: already running ====="
      exit 0
    fi
    run_scraper
  else
    echo "===== $(timestamp) scraper warning: flock not found; running without lock ====="
    run_scraper
  fi
} >> "$LOG_FILE" 2>&1

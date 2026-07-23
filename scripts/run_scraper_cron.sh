#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

log_dir="${SCRAPER_LOG_DIR:-${repo_root}/logs}"
mkdir -p "${log_dir}"

run_id="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")}"
export RUN_ID="${run_id}"

final_log_file="${log_dir}/scraper-${run_id}.log"
log_file="$(mktemp "${log_dir}/scraper-${run_id}.XXXXXX")"
latest_log="${log_dir}/latest.log"
lock_file="${SCRAPER_LOCK_FILE:-${repo_root}/.scraper.lock}"
rscript_bin="${RSCRIPT_BIN:-Rscript}"
SCRAPER_RESULT_FILE=""
SCRAPER_STATUS=""

exec >>"${log_file}" 2>&1

log() {
  printf '[%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"
}

run_step() {
  local label="$1"
  shift

  log "Starting ${label}"
  "$@"
  local status=$?

  if [ "${status}" -ne 0 ]; then
    log "Failed ${label} with exit code ${status}"
    exit "${status}"
  fi

  log "Finished ${label}"
}

cd "${repo_root}" || exit 1

if [[ -f "${repo_root}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "${repo_root}/.env"
  set +a
fi
rscript_bin="${RSCRIPT_BIN:-${rscript_bin}}"

run_scraper() {
  SCRAPER_RESULT_FILE="$(mktemp "${log_dir}/scraper-result.XXXXXX")"
  export SCRAPER_RESULT_FILE

  "${rscript_bin}" scripts/run_scraper.R
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
  done < "${SCRAPER_RESULT_FILE}"

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
    log "Scraper result file is missing."
    return 1
  fi

  if ! scraper_status="$(result_value status)"; then
    log "Scraper result file is missing status."
    return 1
  fi
  SCRAPER_STATUS="$scraper_status"
  if ! revision_id="$(result_value revision_id)"; then
    log "Scraper result file is missing revision_id."
    return 1
  fi
  if ! page_key="$(result_value page_key)"; then
    log "Scraper result file is missing page_key."
    return 1
  fi

  case "$scraper_status" in
    success)
      if [[ -z "${POLL_OF_POLLS_DATA_DIR:-}" ]]; then
        log "POLL_OF_POLLS_DATA_DIR is required after scraper success."
        return 1
      fi

      if [[ "$POLL_OF_POLLS_DATA_DIR" != /* ]]; then
        log "POLL_OF_POLLS_DATA_DIR must be an absolute path."
        return 1
      fi

      data_dir="${POLL_OF_POLLS_DATA_DIR%/}"
      downstream_script="$data_dir/scripts/run_pipeline_cron.sh"
      if [[ ! -f "$downstream_script" ]]; then
        log "Downstream script not found at ${downstream_script}."
        return 1
      fi

      downstream_run_id="wiki-${revision_id}-$(date -u +"%Y%m%dT%H%M%SZ")"
      log "Starting downstream poll artifacts page_key=${page_key} revision_id=${revision_id} run_id=${downstream_run_id}"
      if (
        cd "$data_dir"
        RUN_ID="$downstream_run_id" bash "$downstream_script"
      ); then
        log "Finished downstream poll artifacts run_id=${downstream_run_id}"
      else
        downstream_status=$?
        log "Failed downstream poll artifacts run_id=${downstream_run_id} with exit code ${downstream_status}"
        return "$downstream_status"
      fi
      ;;
    no_change)
      log "Skipping downstream poll artifacts because scraper status=no_change page_key=${page_key} revision_id=${revision_id}"
      ;;
    *)
      log "Unexpected scraper status=${scraper_status}."
      return 1
      ;;
  esac
}

cleanup() {
  local exit_status=$?

  trap - EXIT

  if [[ -n "${SCRAPER_RESULT_FILE:-}" ]]; then
    rm -f "${SCRAPER_RESULT_FILE}"
  fi

  if [[ "${exit_status}" -eq 0 && "${SCRAPER_STATUS:-}" == "no_change" ]]; then
    rm -f "${log_file}"
  else
    mv -f "${log_file}" "${final_log_file}"
    ln -sfn "$(basename "${final_log_file}")" "${latest_log}" 2>/dev/null || true
  fi

  exit "${exit_status}"
}

trap cleanup EXIT

exec 9>"${lock_file}"
if command -v flock >/dev/null 2>&1; then
  if ! flock -n 9; then
    log "Another scraper run is already active; exiting."
    exit 75
  fi
else
  log "flock is not available; continuing without an inter-run lock."
fi

log "Scraper run_id=${RUN_ID}"
log "Repository root=${repo_root}"
log "Log file=${final_log_file}"
log "Rscript=${rscript_bin}"

run_step "scrape Wikipedia polls" run_scraper
run_step "run downstream poll artifacts if needed" run_downstream_if_needed

log "Scraper pipeline completed successfully"

#!/usr/bin/env bash
# ============================================================
# lib/logger.sh — Module de logging pour wooby-tts
# Source ce fichier dans vos scripts :
#   source "$(dirname "$0")/lib/logger.sh"
# ============================================================

# ── Configuration ─────────────────────────────────────────────
LOG_DIR="${WOOBY_LOG_DIR:-${HOME}/.local/share/wooby-tts}"
LOG_FILE="${LOG_DIR}/wooby-tts.log"
LOG_MAX_BYTES=$((5 * 1024 * 1024))  # 5 MB
LOG_KEEP_FILES=3

# ── Initialisation ─────────────────────────────────────────────
_log_init() {
  mkdir -p "$LOG_DIR"
}

# ── Rotation des logs ──────────────────────────────────────────
_log_rotate() {
  if [[ ! -f "$LOG_FILE" ]]; then return; fi
  local size
  size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
  if (( size < LOG_MAX_BYTES )); then return; fi

  # Décaler les archives existantes
  for i in $(seq $((LOG_KEEP_FILES - 1)) -1 1); do
    [[ -f "${LOG_FILE}.${i}" ]] && mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
  done
  mv "$LOG_FILE" "${LOG_FILE}.1"
  # Supprimer les archives au-delà de la limite
  for i in $(seq $((LOG_KEEP_FILES + 1)) $((LOG_KEEP_FILES + 5))); do
    rm -f "${LOG_FILE}.${i}"
  done
}

# ── Écriture d'une ligne de log ────────────────────────────────
_log_write() {
  local level="$1"
  local message="$2"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local line="[${ts}] [${level}] ${message}"

  _log_init
  _log_rotate
  echo "$line" >> "$LOG_FILE"
}

# ── API publique ───────────────────────────────────────────────

# log_info "message"
log_info() {
  _log_write "INFO " "$1"
}

# log_warn "message"
log_warn() {
  _log_write "WARN " "$1"
}

# log_error "message"
log_error() {
  _log_write "ERROR" "$1"
}

# log_metric "key" "value"
# Exemple : log_metric "transcription_time_ms" "342"
log_metric() {
  local key="$1"
  local value="$2"
  _log_write "METR " "key=${key} value=${value}"
}

# log_run_start — Marque le début d'une exécution avec un RUN_ID unique
# Utilisation : RUN_ID=$(log_run_start)
log_run_start() {
  local run_id
  run_id=$(date -u +"%Y%m%dT%H%M%SZ")_$$
  _log_write "INFO " "=== RUN START id=${run_id} duration_requested=${RECORD_SECONDS:-?}s ==="
  echo "$run_id"
}

# log_run_end "run_id" "exit_code"
log_run_end() {
  local run_id="$1"
  local exit_code="$2"
  if [[ "$exit_code" == "0" ]]; then
    _log_write "INFO " "=== RUN END id=${run_id} status=OK ==="
  else
    _log_write "ERROR" "=== RUN END id=${run_id} status=FAIL exit_code=${exit_code} ==="
  fi
}

# ms_now — Retourne le timestamp en millisecondes
ms_now() {
  python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo "0"
}

# elapsed_ms "start_ms" — retourne le nombre de ms écoulées
elapsed_ms() {
  local start="$1"
  local now
  now=$(ms_now)
  echo $(( now - start ))
}

# ── Export des fonctions pour les sous-shells ──────────────────
export -f log_info log_warn log_error log_metric log_run_start log_run_end ms_now elapsed_ms
export LOG_FILE LOG_DIR

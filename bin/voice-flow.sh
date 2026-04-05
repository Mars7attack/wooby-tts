#!/usr/bin/env bash
# ============================================================
# voice-flow.sh — Local-AI Voice Flow (Parakeet Edition)
# Capture micro → Transcription locale → Injection au curseur
# ============================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$BIN_DIR")"
MODEL_DIR="${REPO_DIR}/models/parakeet-tdt"
AUDIO_FILE="/tmp/wooby-speech.wav"
PID_FILE="/tmp/wooby-recording.pid"

# Charger la librairie de logs
if [[ -f "${BIN_DIR}/lib/logger.sh" ]]; then
  source "${BIN_DIR}/lib/logger.sh"
else
  log_info() { echo "INFO: $1"; }
  log_error() { echo "ERROR: $1" >&2; }
  log_metric() { :; }
  log_run_start() { echo "run_$(date +%s)"; }
  log_run_end() { :; }
  ms_now() { date +%s000; }
  elapsed_ms() { echo 0; }
fi

# Modèle... (chemins inchangés)
ENCODER="${MODEL_DIR}/encoder.int8.onnx"
DECODER="${MODEL_DIR}/decoder.int8.onnx"
JOINER="${MODEL_DIR}/joiner.int8.onnx"
TOKENS="${MODEL_DIR}/tokens.txt"
SOX="${SOX_BIN:-/opt/homebrew/bin/sox}"
PYTHON="${PYTHON_BIN:-/Library/Frameworks/Python.framework/Versions/3.13/bin/python3}"

# ── Actions ───────────────────────────────────────────────────

start_recording() {
  # Gérer un PID orphelin
  if [[ -f "$PID_FILE" ]]; then
    local old_pid=$(cat "$PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
      log_error "Un enregistrement est déjà en cours (PID: $old_pid)."
      exit 1
    fi
    rm -f "$PID_FILE"
  fi

  log_info "Démarrage de l'enregistrement..."
  rm -f "$AUDIO_FILE"
  afplay /System/Library/Sounds/Tink.aiff 2>/dev/null &
  
  # Lancer sox en arrière-plan
  if ! "$SOX" -d -r 16000 -c 1 -b 16 "$AUDIO_FILE" >/dev/null 2>&1 & then
    log_error "Impossible de lancer sox. Vérifiez les permissions Micro."
    exit 1
  fi
  local sox_pid=$!
  echo "$sox_pid" > "$PID_FILE"
  log_info "Sox lancé (PID: $sox_pid)."
}

stop_recording() {
  if [[ ! -f "$PID_FILE" ]]; then
    log_error "Aucun enregistrement en cours."
    exit 1
  fi
  
  local sox_pid
  sox_pid=$(cat "$PID_FILE")
  log_info "Arrêt de l'enregistrement (PID: $sox_pid)..."
  
  kill "$sox_pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  afplay /System/Library/Sounds/Morse.aiff &
  
  sleep 0.2 # Laisser sox finir d'écrire le WAV
}

# ── Transcription & Injection (Inchangé mais factorisé) ───────

run_pipeline() {
  if [[ ! -f "$AUDIO_FILE" ]] || [[ ! -s "$AUDIO_FILE" ]]; then
    log_error "Fichier audio vide ou manquant. L'enregistrement a probablement échoué."
    exit 1
  fi
  
  log_info "Transcription en cours..."
  local text
  text=$(transcribe)
  inject_text "$text"
}

# (Fonction transcribe et inject_text restent les mêmes qu'avant...)
transcribe() {
  local start_t=$(ms_now)
  local text
  text=$("$PYTHON" - <<PYEOF
import sherpa_onnx, wave, array, re, sys
try:
    recognizer = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder="${ENCODER}", decoder="${DECODER}", joiner="${JOINER}", tokens="${TOKENS}",
        num_threads=4, sample_rate=16000, feature_dim=128, model_type="", decoding_method="greedy_search", debug=False
    )
    with wave.open("${AUDIO_FILE}", "rb") as f:
        sample_rate = f.getframerate()
        raw = f.readframes(f.getnframes())
    samples = array.array("h", raw)
    floats = [s / 32768.0 for s in samples]
    stream = recognizer.create_stream()
    stream.accept_waveform(sample_rate, floats)
    recognizer.decode_stream(stream)
    text = re.sub(r'<[^>]+>', '', stream.result.text.strip())
    print(text.strip())
except Exception as e:
    print(f"PYTHON_ERROR: {str(e)}", file=sys.stderr); sys.exit(1)
PYEOF
)
  if [[ $? -ne 0 ]]; then log_error "Transcription failed: $text"; exit 1; fi
  echo "$text"
}

inject_text() {
  local text="$1"
  [[ -z "$text" ]] && return 0
  log_info "Injection : \"$text\""
  local previous_clip=$(osascript -e 'get the clipboard' 2>/dev/null || echo "")
  echo -n "$text" | pbcopy
  osascript -e 'tell application "System Events" to keystroke "v" using {command down}' 2>/dev/null
  sleep 0.3
  echo -n "$previous_clip" | pbcopy
}

# ── Main ──────────────────────────────────────────────────────

case "${1:-}" in
  --start)
    start_recording
    ;;
  --stop)
    run_id=$(log_run_start)
    stop_recording
    run_pipeline
    log_run_end "$run_id" 0
    ;;
  *)
    echo "Usage: $0 {--start|--stop}"
    exit 1
    ;;
esac

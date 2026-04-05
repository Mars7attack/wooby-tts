#!/usr/bin/env bash
# ============================================================
# health-check.sh — Vérification de l'environnement wooby-tts
# Vérifie toutes les dépendances sans lancer d'enregistrement.
# Exit 0 si tout est OK, exit 1 si au moins une chose KO.
# Usage :
#   ./bin/health-check.sh          # rapport lisible
#   ./bin/health-check.sh --json   # rapport JSON (pour parsing agent)
# ============================================================

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$BIN_DIR")"
MODEL_DIR="${REPO_DIR}/models/parakeet-tdt"
SOX="/opt/homebrew/bin/sox"
PYTHON="/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"

set -uo pipefail

JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

# Résultats (Bash 3.2 compatible - no associative arrays)
# Conventions: res_{key} for status, det_{key} for details

check() {
  local key="$1"
  local ok="$2"
  local detail="${3:-}"
  eval "res_${key}=\"\$ok\""
  eval "det_${key}=\"\$detail\""
}

# ── 1. sox ────────────────────────────────────────────────────
if [[ -x "$SOX" ]]; then
  SOX_VERSION=$("$SOX" --version 2>&1 | head -1 || echo "unknown")
  check sox ok "$SOX_VERSION"
else
  check sox fail "introuvable : $SOX — brew install sox"
fi

# ── 2. Python ─────────────────────────────────────────────────
if [[ -x "$PYTHON" ]]; then
  PY_VERSION=$("$PYTHON" --version 2>&1)
  check python ok "$PY_VERSION"
else
  check python fail "introuvable : $PYTHON"
fi

# ── 3. sherpa_onnx ────────────────────────────────────────────
# On utilise une variable temporaire pour le statut python car res_python n'est pas directement accessible via $
eval "status_py=\$res_python"
if [[ "$status_py" == "ok" ]]; then
  SHERPA_VERSION=$("$PYTHON" -c "import sherpa_onnx; print(sherpa_onnx.__version__)" 2>/dev/null || echo "")
  if [[ -n "$SHERPA_VERSION" ]]; then
    check sherpa_onnx ok "v${SHERPA_VERSION}"
  else
    check sherpa_onnx fail "non installé — pip install sherpa-onnx"
  fi
else
  check sherpa_onnx skip "Python KO, test ignoré"
fi

# ── 4. Fichiers modèle ────────────────────────────────────────
for fname in encoder.int8.onnx decoder.int8.onnx joiner.int8.onnx tokens.txt; do
  fpath="${MODEL_DIR}/${fname}"
  # Remplacer . et - par _ pour les noms de variables
  key="model_${fname//./_}"
  key="${key//-/_}"
  if [[ -f "$fpath" ]]; then
    fsize=$(du -sh "$fpath" | cut -f1)
    check "$key" ok "${fpath} (${fsize})"
  else
    check "$key" fail "manquant : $fpath"
  fi
done

# ── 5. Répertoire de logs ──────────────────────────────────────
LOG_DIR="${WOOBY_LOG_DIR:-${HOME}/.local/share/wooby-tts}"
LOG_FILE="${LOG_DIR}/wooby-tts.log"
if [[ -d "$LOG_DIR" ]]; then
  if [[ -f "$LOG_FILE" ]]; then
    log_size=$(du -sh "$LOG_FILE" | cut -f1)
    log_lines=$(wc -l < "$LOG_FILE" | awk '{print $1}')
    check logs ok "$(basename "$LOG_FILE") (${log_size}, ${log_lines} lignes)"
  else
    check logs ok "répertoire OK, pas encore de logs"
  fi
else
  check logs warn "répertoire inexistant (sera créé au 1er run)"
fi

# ── Calcul du statut global ────────────────────────────────────
overall=0
# Liste des clés à vérifier
ALL_KEYS="sox python sherpa_onnx model_encoder_int8_onnx model_decoder_int8_onnx model_joiner_int8_onnx model_tokens_txt logs"

for key in $ALL_KEYS; do
  eval "status=\$res_$key"
  [[ "$status" == "fail" ]] && overall=1
done

# ── Affichage ─────────────────────────────────────────────────
if [[ $JSON_MODE -eq 1 ]]; then
  echo "{"
  echo "  \"overall\": $([ $overall -eq 0 ] && echo '"ok"' || echo '"fail"'),"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"checks\": {"
  first=1
  for key in $ALL_KEYS; do
    [[ $first -eq 0 ]] && echo ","
    eval "status=\$res_$key"
    eval "detail=\$det_$key"
    echo -n "    \"${key}\": {\"status\": \"${status}\", \"detail\": \"${detail}\"}"
    first=0
  done
  echo ""
  echo "  }"
  echo "}"
else
  echo "━━━ wooby-tts health check ━━━"
  echo ""
  for key in $ALL_KEYS; do
    eval "status=\$res_$key"
    eval "detail=\$det_$key"
    case "$status" in
      ok)   icon="✅" ;;
      warn) icon="⚠️ " ;;
      skip) icon="⏭️ " ;;
      *)    icon="❌" ;;
    esac
    printf "  %s  %-35s %s\n" "$icon" "$key" "$detail"
  done
  echo ""
  if [[ $overall -eq 0 ]]; then
    echo "✅ Environnement OK — prêt à dicter."
  else
    echo "❌ Problèmes détectés — voir les lignes ❌ ci-dessus."
  fi
fi

exit $overall

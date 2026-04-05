#!/usr/bin/env bash
# ============================================================
# show-logs.sh — Consulter les logs wooby-tts
# Usage :
#   ./bin/show-logs.sh             # Dernières 50 lignes
#   ./bin/show-logs.sh --errors    # Uniquement les erreurs/warnings
#   ./bin/show-logs.sh --last N    # Les N dernières exécutions
#   ./bin/show-logs.sh --all       # Tout le fichier de log
#   ./bin/show-logs.sh --path      # Affiche juste le chemin du fichier de log
# ============================================================

set -euo pipefail

LOG_DIR="${WOOBY_LOG_DIR:-${HOME}/.local/share/wooby-tts}"
LOG_FILE="${LOG_DIR}/wooby-tts.log"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "ℹ️  Aucun log trouvé : $LOG_FILE"
  echo "   Lance d'abord : ./bin/voice-flow.sh"
  exit 0
fi

MODE="${1:-}"
ARG2="${2:-50}"

case "$MODE" in
  --path)
    echo "$LOG_FILE"
    ;;

  --errors)
    echo "━━━ Erreurs & Warnings dans $LOG_FILE ━━━"
    grep -E '\[(ERROR|WARN )\]' "$LOG_FILE" || echo "(aucune erreur trouvée)"
    ;;

  --last)
    N="${ARG2}"
    echo "━━━ Dernières ${N} exécutions ━━━"
    # Chaque exécution commence par "RUN START"
    grep -n "RUN START" "$LOG_FILE" | tail -"$N" | while IFS=: read -r lineno rest; do
      echo ""
      echo "── Run (ligne ${lineno}) ──────────────────────────────"
      # Afficher les lignes entre ce RUN START et le prochain RUN END
      awk -v start="$lineno" '
        NR >= start {
          print
          if (/RUN END/) exit
        }
      ' "$LOG_FILE"
    done
    ;;

  --all)
    echo "━━━ Logs complets : $LOG_FILE ━━━"
    cat "$LOG_FILE"
    ;;

  --clear)
    read -p "⚠️  Supprimer tous les logs ? (y/N) " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      rm -f "$LOG_FILE" "${LOG_FILE}".{1..3}
      echo "✅ Logs supprimés."
    else
      echo "Annulé."
    fi
    ;;

  *)
    # Défaut : dernières 50 lignes
    LINES="${MODE:-50}"
    if [[ "$LINES" =~ ^[0-9]+$ ]]; then
      echo "━━━ Dernières ${LINES} lignes de $LOG_FILE ━━━"
      tail -"$LINES" "$LOG_FILE"
    else
      echo "━━━ Dernières 50 lignes de $LOG_FILE ━━━"
      tail -50 "$LOG_FILE"
    fi
    ;;
esac

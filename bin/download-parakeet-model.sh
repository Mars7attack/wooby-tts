#!/usr/bin/env bash
# ============================================================
# download-parakeet-model.sh
# Télécharge et installe Parakeet TDT 0.6B v3 (int8, NeMo format)
# depuis les releases officielles sherpa-onnx
# ============================================================

set -euo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MODEL_DIR="${REPO_DIR}/models/parakeet-tdt"
TMP_DIR="/tmp/parakeet-download"

# Modèle exact utilisé par OpenWhispr (NeMo Parakeet TDT 0.6B v3 int8)
ARCHIVE_NAME="sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2"
EXTRACT_DIR_NAME="sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8"
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${ARCHIVE_NAME}"

echo "📥  Téléchargement Parakeet TDT 0.6B v3 (int8, ~680MB)..."
echo "    URL : ${MODEL_URL}"
echo ""

# Vérifier si déjà installé
if [[ -f "${MODEL_DIR}/model.onnx" ]] && [[ -f "${MODEL_DIR}/tokens.txt" ]]; then
  echo "✅  Modèle déjà présent dans ${MODEL_DIR}"
  [[ "${1:-}" == "--force" ]] || { echo "    Utilisez --force pour réinstaller."; exit 0; }
fi

mkdir -p "$TMP_DIR" "$MODEL_DIR"
cd "$TMP_DIR"

# Télécharger l'archive (avec reprise si interrompue)
if [[ ! -f "$ARCHIVE_NAME" ]]; then
  wget -c --show-progress -O "$ARCHIVE_NAME" "$MODEL_URL"
else
  echo "📦  Archive déjà téléchargée, extraction directe..."
fi

echo ""
echo "📦  Extraction..."
tar -xjf "$ARCHIVE_NAME"

EXTRACTED_DIR="${TMP_DIR}/${EXTRACT_DIR_NAME}"

if [[ ! -d "$EXTRACTED_DIR" ]]; then
  # Fallback : chercher n'importe quel dossier parakeet extrait
  EXTRACTED_DIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "*parakeet*" | head -1)
fi

if [[ -z "$EXTRACTED_DIR" ]] || [[ ! -d "$EXTRACTED_DIR" ]]; then
  echo "❌  Erreur : dossier parakeet non trouvé dans l'archive."
  echo "    Contenu de $TMP_DIR :"
  ls -la "$TMP_DIR"
  exit 1
fi

echo "📁  Dossier extrait : $EXTRACTED_DIR"

# Copier les fichiers nécessaires (NeMo format = model.onnx + tokens.txt)
for f in model.onnx tokens.txt; do
  if [[ -f "${EXTRACTED_DIR}/${f}" ]]; then
    cp "${EXTRACTED_DIR}/${f}" "${MODEL_DIR}/${f}"
    size=$(du -sh "${MODEL_DIR}/${f}" | cut -f1)
    echo "   ✅ Copié : $f ($size)"
  else
    echo "   ⚠️  Non trouvé : $f"
    echo "      Contenu du dossier extrait :"
    ls -la "$EXTRACTED_DIR"
  fi
done

# Nettoyage
rm -rf "$TMP_DIR"

echo ""
echo "✅  Modèle installé dans : ${MODEL_DIR}"
echo ""
echo "    Lancez maintenant :"
echo "    ~/repo/local-ai/bin/voice-flow.sh"

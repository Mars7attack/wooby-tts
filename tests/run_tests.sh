#!/usr/bin/env bash
# ============================================================
# run_tests.sh — Lanceur de tests pour wooby-tts
# ============================================================

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TEST_DIR")"
BIN_DIR="${REPO_DIR}/bin"
TEST_DIR="${REPO_DIR}/tests"

# Couleurs
BOLD='\033[1m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}🚀 Lancement de la suite de tests wooby-tts${NC}"
echo "-------------------------------------------"

# 1. Tests unitaires Python
echo -e "\n${BOLD}🐍 1. Tests unitaires Python (unittest)${NC}"
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 -m unittest "$TEST_DIR/test_transcribe.py" -v

# 2. Tests d'intégration Shell
echo -e "\n${BOLD}🐚 2. Tests d'intégration Shell${NC}"
bash "$TEST_DIR/test_pipeline.sh"

# 3. Health Check
echo -e "\n${BOLD}🏥 3. Health Check environnemental${NC}"
bash "$BIN_DIR/health-check.sh"

echo "-------------------------------------------"
echo -e "${BOLD}${CYAN}✅ Vérification terminée.${NC}"

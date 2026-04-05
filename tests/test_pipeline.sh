#!/usr/bin/env bash
# ============================================================
# test_pipeline.sh — Tests d'intégration pour voice-flow.sh
# Tests des cas d'erreur sans enregistrement réel.
# ============================================================

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TEST_DIR")"
BIN_DIR="${REPO_DIR}/bin"
VOICE_FLOW="${BIN_DIR}/voice-flow.sh"
TEMP_LOG_DIR="/tmp/wooby-test-logs"

# Initialisation
mkdir -p "$TEMP_LOG_DIR"
export WOOBY_LOG_DIR="$TEMP_LOG_DIR"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass=0
fail=0

test_case() {
    local name="$1"
    echo -n "🧪 $name... "
}

assert_exit() {
    local code="$1"
    local expected="$2"
    if [[ "$code" -eq "$expected" ]]; then
        echo -e "${GREEN}PASS${NC}"
        pass=$((pass + 1))
    else
        echo -e "${RED}FAIL (expected $expected, got $code)${NC}"
        fail=$((fail + 1))
    fi
}

# ── Test 1 : Dépendances manquantes ──
test_case "check_deps failure (missing sox)"
(
    # On force un chemin inexistant pour sox
    export SOX_BIN="/tmp/non_existent_sox"
    # On appelle un sous-shell qui exécute juste check_deps via voice-flow.sh
    # Comme on ne peut pas appeler une fonction bash interne facilement, 
    # on simule le run complet mais on s'attend à un exit 1 rapide.
    bash "$VOICE_FLOW" > /dev/null 2>&1
)
assert_exit $? 1

# ── Test 2 : Health check normal ──
test_case "Health check returns 0 (normal env)"
bash "$BIN_DIR/health-check.sh" > /dev/null
assert_exit $? 0

test_case "Show logs script works"
bash "$BIN_DIR/show-logs.sh" --path > /dev/null
assert_exit $? 0

echo ""
echo "📊 Résultats : $pass PASS, $fail FAIL"
[[ $fail -eq 0 ]] || exit 1

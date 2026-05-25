#!/usr/bin/env bash
# scaffold-usecase.sh — Generate usecase for a module
# Usage: ./scaffold-usecase.sh <ModuleName> [--force] [module_path]
#
# If module_path is provided (e.g. github.com/enigma-id/theproject):
#   Uses it directly — works without go.mod
# If omitted:
#   Detects from go.mod (must exist)
#
# Generates:
#   src/usecase/<module>.go

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <ModuleName> [--force] [module_path]"
  echo "  ModuleName: PascalCase, e.g. Shipping, OrderManagement"
  exit 1
fi

FORCE=""
MODULE_ARG=""
MODULE_INPUT="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE="--force"; shift ;;
    -*) fail "Unknown flag: $1" ;;
    *)  MODULE_ARG="$1"; shift ;;
  esac
done

# ── Resolve SERVICE_MODULE ────────────────────────────────────────────────────
if [[ -n "$MODULE_ARG" ]]; then
  SERVICE_MODULE="$MODULE_ARG"
  SERVICE_NAME="$(basename "$SERVICE_MODULE")"
elif [[ -f "go.mod" ]]; then
  detect_service_module
else
  fail "No go.mod found. Pass module path as argument: $0 ModuleName github.com/enigma-id/theproject"
fi

derive_module "$MODULE_INPUT"

echo "=== Scaffold Usecase: $MODULE_NAME ==="
echo "  Module path: $SERVICE_MODULE"
echo ""

mkdir -p src/usecase
generate "$TEMPLATES/usecase.tpl" "src/usecase/${MODULE_LOWER}.go" "$FORCE"

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Wire entity/repository into the usecase"
echo "  2. Add business logic methods"
echo "  3. Run: scaffold-factory.sh $MODULE_NAME"
echo "  4. Run: scaffold-handler.sh $MODULE_NAME"

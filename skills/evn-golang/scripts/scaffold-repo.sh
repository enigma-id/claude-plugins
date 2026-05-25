#!/usr/bin/env bash
# scaffold-repo.sh — Generate repository for a given entity
# Usage: ./scaffold-repo.sh <EntityName> [--force] [module_path]
#
# If module_path is provided (e.g. github.com/enigma-id/theproject):
#   Uses it directly — works without go.mod
# If omitted:
#   Detects from go.mod (must exist)
#
# Generates:
#   src/repository/<entity>.go

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <EntityName> [--force] [module_path]"
  echo "  EntityName: PascalCase, e.g. Warehouse, DeliveryPlan"
  exit 1
fi

FORCE=""
MODULE_ARG=""
ENTITY_ARG="$1"
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
  fail "No go.mod found. Pass module path as argument: $0 EntityName github.com/enigma-id/theproject"
fi

derive_entity "$ENTITY_ARG"

# Verify entity exists
if [[ ! -f "entity/${ENTITY_LOWER}.go" ]]; then
  warn "entity/${ENTITY_LOWER}.go not found — run scaffold-entity.sh first"
  echo "  Continuing anyway..."
fi

# Auto-detect TABLE_NAME from entity's bun tag
if [[ -f "entity/${ENTITY_LOWER}.go" ]]; then
  TABLE_NAME="$(grep -o 'bun:"table:[^,"]*' "entity/${ENTITY_LOWER}.go" | head -1 | sed 's/bun:"table://')"
fi
TABLE_NAME="${TABLE_NAME:-$ENTITY_PLURAL}"

echo "=== Scaffold Repository: $ENTITY_NAME ==="
echo "  Module: $SERVICE_MODULE"
echo "  Entity: entity.${ENTITY_NAME}"
echo "  Table:  ${TABLE_NAME}"
echo ""

generate "$TEMPLATES/repository.tpl" "src/repository/${ENTITY_LOWER}.go" "$FORCE"

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Update searchFields and preloadRelations in the repository"
echo "  2. Add custom query methods if needed"
echo "  3. Run: scaffold-usecase.sh $ENTITY_NAME"

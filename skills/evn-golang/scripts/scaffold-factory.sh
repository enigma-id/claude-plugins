#!/usr/bin/env bash
# scaffold-factory.sh — Create or update usecase Factory
# Usage: ./scaffold-factory.sh <ModuleName> [--force] [module_path]
#
# If module_path is provided (e.g. github.com/enigma-id/theproject):
#   Uses it directly — works without go.mod
# If omitted:
#   Detects from go.mod (must exist)
#
# If src/usecase/factory.go doesn't exist:
#   Creates it with the given module as first usecase
#
# If src/usecase/factory.go exists:
#   Appends the module's usecase field, constructor, and WithContext line

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

# Verify usecase exists
if [[ ! -f "src/usecase/${MODULE_LOWER}.go" ]]; then
  warn "src/usecase/${MODULE_LOWER}.go not found — run scaffold-usecase.sh first"
fi

echo "=== Scaffold Factory: $MODULE_NAME ==="
echo "  Module path: $SERVICE_MODULE"
echo ""

FACTORY_FILE="src/usecase/factory.go"

if [[ ! -f "$FACTORY_FILE" ]]; then
  mkdir -p src/usecase
  generate "$TEMPLATES/factory.tpl" "$FACTORY_FILE" "$FORCE"
else
  if grep -q "${MODULE_NAME}Usecase\|${MODULE_NAME} \*${MODULE_NAME}Usecase" "$FACTORY_FILE" 2>/dev/null; then
    warn "Factory already has ${MODULE_NAME}Usecase — skipped"
  else
    awk -v field="	${MODULE_NAME} *${MODULE_NAME}Usecase" '
      /type Factory struct \{/ { print; getline; print field; }
      { print }
    ' "$FACTORY_FILE" > "${FACTORY_FILE}.tmp" && mv "${FACTORY_FILE}.tmp" "$FACTORY_FILE"

    awk -v line="		${MODULE_NAME}: New${MODULE_NAME}Usecase()," '
      /func NewFactory\(\)/ { in_func=1 }
      in_func && /return &Factory\{/ { print; getline; print line; in_func=0; next }
      { print }
    ' "$FACTORY_FILE" > "${FACTORY_FILE}.tmp" && mv "${FACTORY_FILE}.tmp" "$FACTORY_FILE"

    awk -v line="		${MODULE_NAME}: f.${MODULE_NAME}.WithContext(ctx)," '
      /func \(f \*Factory\) WithContext/ { in_func=1 }
      in_func && /return &Factory\{/ { print; getline; print line; in_func=0; next }
      { print }
    ' "$FACTORY_FILE" > "${FACTORY_FILE}.tmp" && mv "${FACTORY_FILE}.tmp" "$FACTORY_FILE"

    info "Updated $FACTORY_FILE — added ${MODULE_NAME}Usecase"
  fi
fi

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Verify factory.go has all usecases"
echo "  2. Run: go build ./..."

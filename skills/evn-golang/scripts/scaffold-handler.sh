#!/usr/bin/env bash
# scaffold-handler.sh — Generate REST handler + request files for a module
# Usage: ./scaffold-handler.sh <ModuleName> [--force] [module_path]
#
# If module_path is provided (e.g. github.com/enigma-id/theproject):
#   Uses it directly — works without go.mod
# If omitted:
#   Detects from go.mod (must exist)
#
# Generates:
#   src/handler/rest/<module>/handler.go
#   src/handler/rest/<module>/request_get.go
#   src/handler/rest/<module>/request_create.go
#   src/handler/rest/<module>/request_update.go
#   src/handler/rest/<module>/request_delete.go
#
# Also updates src/handler.go to register the new module routes.

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

# Verify dependencies
if [[ ! -f "src/usecase/${MODULE_LOWER}.go" ]]; then
  warn "src/usecase/${MODULE_LOWER}.go not found — run scaffold-usecase.sh first"
fi

echo "=== Scaffold Handler: $MODULE_NAME ==="
echo "  Module path: $SERVICE_MODULE"
echo "  Routes: /${MODULE_PLURAL} (CRUD)"
echo ""

HANDLER_DIR="src/handler/rest/${MODULE_LOWER}"
mkdir -p "$HANDLER_DIR"

generate "$TEMPLATES/handler/handler.tpl"        "$HANDLER_DIR/handler.go"        "$FORCE"
generate "$TEMPLATES/handler/request_get.tpl"    "$HANDLER_DIR/request_get.go"    "$FORCE"
generate "$TEMPLATES/handler/request_create.tpl" "$HANDLER_DIR/request_create.go" "$FORCE"
generate "$TEMPLATES/handler/request_update.tpl" "$HANDLER_DIR/request_update.go" "$FORCE"
generate "$TEMPLATES/handler/request_delete.tpl" "$HANDLER_DIR/request_delete.go" "$FORCE"

# ── Register routes in src/handler.go ────────────────────────────────────────
HANDLER_FILE="src/handler.go"

if [[ -f "$HANDLER_FILE" ]]; then
  IMPORT_LINE="h${MODULE_LOWER} \"${SERVICE_MODULE}/src/handler/rest/${MODULE_LOWER}\""
  REGISTER_LINE="h${MODULE_LOWER}.RegisterHandler(s)"

  if ! grep -q "h${MODULE_LOWER}" "$HANDLER_FILE" 2>/dev/null; then
    if grep -q "import" "$HANDLER_FILE"; then
      awk -v imp="	${IMPORT_LINE}" '
        /^import \(/ { in_import=1 }
        in_import && /^\)/ { print imp; in_import=0 }
        { print }
      ' "$HANDLER_FILE" > "${HANDLER_FILE}.tmp" && mv "${HANDLER_FILE}.tmp" "$HANDLER_FILE"
      info "Added import to src/handler.go"
    fi
  else
    warn "Import h${MODULE_LOWER} already exists in src/handler.go — skipped"
  fi

  if ! grep -q "${REGISTER_LINE}" "$HANDLER_FILE" 2>/dev/null; then
    if grep -q "RegisterRestRoutes" "$HANDLER_FILE"; then
      awk -v reg="	${REGISTER_LINE}" -v mod="${MODULE_NAME}" '
        /func RegisterRestRoutes/ { found=1 }
        found && /^}/ && !added {
          print "\t// " mod " module"
          print reg
          added=1
        }
        { print }
      ' "$HANDLER_FILE" > "${HANDLER_FILE}.tmp" && mv "${HANDLER_FILE}.tmp" "$HANDLER_FILE"
      info "Registered ${MODULE_NAME} routes in src/handler.go"
    fi
  else
    warn "${REGISTER_LINE} already exists — skipped"
  fi
else
  warn "src/handler.go not found — run scaffold-init.sh first"
fi

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Add request fields to request_create.go and request_update.go"
echo "  2. Add validation rules in Validate() methods"
echo "  3. Update permission codes in handler.go RegisterHandler()"
echo "  4. Run: go build ./..."

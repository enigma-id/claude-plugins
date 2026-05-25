#!/usr/bin/env bash
# scaffold-init.sh — Initialize service directory structure
# Usage: ./scaffold-init.sh [module_path] [--force]
#
# If module_path is provided (e.g. github.com/enigma-id/theproject):
#   Sets SERVICE_MODULE and SERVICE_NAME from it — works without go.mod
# If module_path is omitted:
#   Detects from go.mod (must exist in current directory)
#
# Creates the fixed service skeleton:
#   main.go
#   src/handler.go
#   src/permission.go
#   src/subscriber.go
#   entity/              (empty dir)
#   src/repository/       (empty dir)
#   src/usecase/        (empty dir)
#   src/handler/rest/    (empty dir)
#   src/event/publisher/  (empty dir)
#   src/event/subscriber/ (empty dir)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ── Parse arguments ──────────────────────────────────────────────────────────
FORCE=""
MODULE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE="--force"; shift ;;
    -*) fail "Unknown flag: $1" ;;
    *)  MODULE_ARG="$1"; shift ;;
  esac
done

# ── Resolve SERVICE_MODULE and SERVICE_NAME ─────────────────────────────────
if [[ -n "$MODULE_ARG" ]]; then
  # Use provided module path
  SERVICE_MODULE="$MODULE_ARG"
  SERVICE_NAME="$(basename "$SERVICE_MODULE")"
elif [[ -f "go.mod" ]]; then
  # Detect from go.mod
  detect_service_module
else
  fail "No go.mod found. Pass module path as argument: $0 github.com/enigma-id/theproject"
fi

echo "=== Scaffold Init: $SERVICE_NAME ==="
echo "  Module path: $SERVICE_MODULE"
echo ""

# Init templates only use SERVICE_* — set others empty for render()
ENTITY_NAME=""
ENTITY_LOWER=""
ENTITY_PLURAL=""
ENTITY_UPPER=""
MODULE_NAME=""
MODULE_LOWER=""
MODULE_PLURAL=""
MODULE_UPPER=""

# ── Create directory structure ────────────────────────────────────────────────
mkdir -p entity
mkdir -p src/repository
mkdir -p src/usecase
mkdir -p src/handler/rest
mkdir -p src/event/publisher
mkdir -p src/event/subscriber
info "Created directory structure"

# ── Generate fixed files ─────────────────────────────────────────────────────
generate "$TEMPLATES/init/main.tpl"        "main.go"             "$FORCE"
generate "$TEMPLATES/init/handler.tpl"     "src/handler.go"      "$FORCE"
generate "$TEMPLATES/init/permission.tpl"  "src/permission.go"   "$FORCE"
generate "$TEMPLATES/init/subscriber.tpl"  "src/subscriber.go"   "$FORCE"

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. go mod init $SERVICE_MODULE  (if not already done)"
echo "  2. Uncomment connection calls in main.go as needed"
echo "  3. Use scaffold-entity.sh to generate entities from SQL"

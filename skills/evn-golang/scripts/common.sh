#!/usr/bin/env bash
# common.sh — Shared variables and helpers for all scaffold scripts
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
fail()  { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }

# ─── Auto-detect SERVICE_MODULE from go.mod ──────────────────────────────────
detect_service_module() {
  if [[ ! -f "go.mod" ]]; then
    fail "go.mod not found — run this script from the service root directory"
  fi
  SERVICE_MODULE="$(head -1 go.mod | awk '{print $2}')"
  SERVICE_NAME="$(basename "$SERVICE_MODULE")"
}

# ─── Singularize helper ──────────────────────────────────────────────────────
# Simple English singularization (handles common cases)
singularize() {
  local word="$1"
  # Remove trailing 's' if present
  if [[ "$word" =~ s$ ]]; then
    echo "${word%s}"
  else
    echo "$word"
  fi
}

# ─── Derive ENTITY variables from PascalCase name ───────────────────────────
# Used by: scaffold-entity.sh, scaffold-repo.sh (data layer)
# Usage: derive_entity "DeliveryPlan"
derive_entity() {
  local name="$1"

  if [[ ! "$name" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
    fail "EntityName must be PascalCase (e.g. Warehouse, DeliveryPlan). Got: $name"
  fi

  ENTITY_NAME="$name"
  # Snake_case for filenames: DeliveryPlans → delivery_plans, Warehouses → warehouses
  ENTITY_LOWER="$(echo "$name" | sed 's/\([A-Z]\)/_\1/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_//')"
  ENTITY_UPPER="$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  ENTITY_PLURAL="${ENTITY_LOWER}s"
  TABLE_NAME="${TABLE_NAME:-$ENTITY_PLURAL}" # can be overridden before calling derive_entity
}

# ─── Derive MODULE variables from PascalCase name ───────────────────────────
# Used by: scaffold-usecase.sh, scaffold-handler.sh, scaffold-factory.sh (business/API layer)
# Usage: derive_module "Shipping"
derive_module() {
  local name="$1"

  if [[ ! "$name" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
    fail "ModuleName must be PascalCase (e.g. Shipping, OrderManagement). Got: $name"
  fi

  MODULE_NAME="$name"
  MODULE_LOWER="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  MODULE_UPPER="$(echo "$name" | tr '[:lower:]' '[:upper:]')"
  MODULE_PLURAL="${MODULE_LOWER}s"
}

# ─── Render template with sed ─────────────────────────────────────────────────
# Usage: render <template_file> <output_file>
# Substitutes both ENTITY_* and MODULE_* vars (whichever are set).
render() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    fail "Template not found: $src"
  fi

  sed -e "s/{{ENTITY_NAME}}/${ENTITY_NAME:-}/g" \
      -e "s/{{ENTITY_LOWER}}/${ENTITY_LOWER:-}/g" \
      -e "s/{{ENTITY_PLURAL}}/${ENTITY_PLURAL:-}/g" \
      -e "s/{{ENTITY_UPPER}}/${ENTITY_UPPER:-}/g" \
      -e "s/{{MODULE_NAME}}/${MODULE_NAME:-}/g" \
      -e "s/{{MODULE_LOWER}}/${MODULE_LOWER:-}/g" \
      -e "s/{{MODULE_PLURAL}}/${MODULE_PLURAL:-}/g" \
      -e "s/{{MODULE_UPPER}}/${MODULE_UPPER:-}/g" \
      -e "s/{{TABLE_NAME}}/${TABLE_NAME:-}/g" \
      -e "s|{{SERVICE_MODULE}}|${SERVICE_MODULE:-}|g" \
      -e "s|{{SERVICE_NAME}}|${SERVICE_NAME:-}|g" \
      "$src" > "$dst"
}

# ─── Generate file (render + log) ────────────────────────────────────────────
# Usage: generate <template_file> <output_file> [--force]
generate() {
  local tpl="$1"
  local dst="$2"
  local force="${3:-}"

  if [[ -f "$dst" && "$force" != "--force" ]]; then
    warn "Skipped $(basename "$dst") — already exists (use --force to overwrite)"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  render "$tpl" "$dst"
  info "Created $dst"
}

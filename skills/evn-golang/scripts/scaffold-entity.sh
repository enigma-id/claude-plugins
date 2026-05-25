#!/usr/bin/env bash
# scaffold-entity.sh — Generate entity from SQL DDL
# Usage: ./scaffold-entity.sh --from-sql <file.sql> [--force] [module_path]
#        echo "CREATE TABLE ..." | ./scaffold-entity.sh --from-stdin [--force] [module_path]
#
# If module_path is provided (e.g. github.com/enigma-id/theproject):
#   Uses it directly — works without go.mod
# If omitted:
#   Detects from go.mod (must exist)
#
# Entity name = table name, PascalCased (no singularization):
#   warehouses → Warehouses, delivery_plans → DeliveryPlans, users → Users
#
# Generates:
#   entity/<entity>.go
#
# Auto-chains to scaffold-repo.sh for repository generation.
#
# Dependencies: bash, sed, awk, python3 (for SQL parsing with paren depth)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ── Parse arguments ──────────────────────────────────────────────────────────
SQL_FILE=""
FROM_STDIN=false
FORCE=""
MODULE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-sql)  SQL_FILE="$2"; shift 2 ;;
    --from-stdin) FROM_STDIN=true; shift ;;
    --force)     FORCE="--force"; shift ;;
    -*) fail "Unknown flag: $1" ;;
    *)  MODULE_ARG="$1"; shift ;;
  esac
done

if [[ -z "$SQL_FILE" && "$FROM_STDIN" == false ]]; then
  fail "SQL input required. Use --from-sql <file.sql> or --from-stdin"
fi

# ── Resolve SERVICE_MODULE and SERVICE_NAME ─────────────────────────────────
if [[ -n "$MODULE_ARG" ]]; then
  SERVICE_MODULE="$MODULE_ARG"
  SERVICE_NAME="$(basename "$SERVICE_MODULE")"
elif [[ -f "go.mod" ]]; then
  detect_service_module
else
  fail "No go.mod found. Pass module path as argument: $0 --from-stdin github.com/enigma-id/theproject"
fi

# ── Read SQL input ───────────────────────────────────────────────────────────
if [[ -n "$SQL_FILE" ]]; then
  if [[ ! -f "$SQL_FILE" ]]; then
    fail "SQL file not found: $SQL_FILE"
  fi
  SQL_INPUT="$(cat "$SQL_FILE")"
else
  SQL_INPUT="$(cat)"
fi

# ── Extract table name from CREATE TABLE ─────────────────────────────────────
extract_table_name_from_sql() {
  local sql="$1"
  echo "$sql" | grep -oi 'CREATE TABLE\( IF NOT EXISTS\)\?[[:space:]]*["]* *[a-z_0-9.]*' \
    | head -1 \
    | awk '{print $NF}' \
    | tr -d '"' \
    | sed 's/.*\.//'
}

TABLE_NAME="$(extract_table_name_from_sql "$SQL_INPUT")"
if [[ -z "$TABLE_NAME" ]]; then
  fail "Could not extract table name from SQL. Ensure it contains CREATE TABLE <name>"
fi

# ── Derive entity name from table name ───────────────────────────────────────
# Entity name = table name singularized, then PascalCased.
# e.g. warehouses → Warehouse, delivery_plans → DeliveryPlan, users → User
table_to_pascal() {
  echo "$1" | awk 'BEGIN{FS="_";OFS="";ORS=""}{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}print}'
}

# Singularize table name before converting to PascalCase
SINGULAR_TABLE="$(singularize "$TABLE_NAME")"
ENTITY_NAME="$(table_to_pascal "$SINGULAR_TABLE")"
# Fix common abbreviations
ENTITY_NAME="${ENTITY_NAME/Id/ID}"
ENTITY_NAME="${ENTITY_NAME/Url/URL}"
ENTITY_NAME="${ENTITY_NAME/Api/API}"
ENTITY_NAME="${ENTITY_NAME/Uuid/UUID}"
# Snake_case for filenames: UserProfiles → user_profiles
ENTITY_LOWER="$(echo "$ENTITY_NAME" | sed 's/\([A-Z]\)/_\1/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_//')"

echo "=== Scaffold Entity ==="
echo "  Module: $SERVICE_MODULE"
echo "  Table:  $TABLE_NAME"
echo "  Entity: $ENTITY_NAME"
echo ""

# ── SQL type → Go type mapping ───────────────────────────────────────────────
sql_to_go_type() {
  local sql_type="$1"
  local nullable="$2"
  sql_type="$(echo "$sql_type" | tr '[:upper:]' '[:lower:]')"
  local go_type=""
  case "$sql_type" in
    uuid)                        go_type="uuid.UUID" ;;
    varchar*|text|char*|citext)  go_type="string" ;;
    int|integer|int4|serial)     go_type="int" ;;
    bigint|int8|bigserial)       go_type="int64" ;;
    smallint|int2)               go_type="int16" ;;
    bool|boolean)                go_type="bool" ;;
    float4|real)                  go_type="float32" ;;
    float8|"double precision"|numeric|decimal*) go_type="float64" ;;
    timestamp*|date)             go_type="time.Time" ;;
    jsonb|json)                  go_type="json.RawMessage" ;;
    bytea)                       go_type="[]byte" ;;
    *)                           go_type="string" ;;
  esac
  if [[ "$nullable" == "true" ]]; then
    case "$go_type" in
      uuid.UUID)       echo "*uuid.UUID" ;;
      string)          echo "*string" ;;
      int)             echo "*int" ;;
      int64)           echo "*int64" ;;
      int16)           echo "*int16" ;;
      bool)            echo "*bool" ;;
      float32)         echo "*float32" ;;
      float64)         echo "*float64" ;;
      time.Time)       echo "*time.Time" ;;
      json.RawMessage) echo "json.RawMessage" ;;
      "[]byte")        echo "[]byte" ;;
      *)               echo "*$go_type" ;;
    esac
  else
    echo "$go_type"
  fi
}

fix_go_name() {
  local name="$1"
  name="${name/Id/ID}"
  name="${name/Url/URL}"
  name="${name/Api/API}"
  name="${name/Http/HTTP}"
  name="${name/Uuid/UUID}"
  name="${name/Sql/SQL}"
  name="${name/Ip/IP}"
  # Remove internal spaces (e.g. "Is Active" → "IsActive")
  name="${name// /}"
  echo "$name"
}

# ── Parse SQL DDL → Go entity ────────────────────────────────────────────────
# Populates global vars: _fields and _imports
parse_sql_to_entity() {
  local sql_input="$1"
  local needs_uuid=false
  local needs_time=false
  local needs_json=false
  _fields=""
  _imports=""

  # Extract column definitions from CREATE TABLE statement
  local col_block
  col_block="$(echo "$sql_input" | tr '\n' ' ' | sed -n 's/.*CREATE TABLE[^(]*(\(.*\)).*/\1/p' | head -1)"
  [[ -z "$col_block" ]] && { echo "Error: Could not parse CREATE TABLE statement"; return 1; }

  # Split by comma, but not commas inside parentheses (e.g. DECIMAL(12,2))
  # Strategy: collect tokens, treating all content inside () as a single token
  local IFS_OLD="$IFS"
  local IFS=','
  local col_def=""
  local depth=0
  local fields_buf=""
  local in_field=false

  for (( i=0; i<${#col_block}; i++ )); do
    local ch="${col_block:$i:1}"
    case "$ch" in
      '(')  depth=$((depth+1)); col_def+="$ch" ;;
      ')')  depth=$((depth-1)); col_def+="$ch" ;;
      ',')  if [[ $depth -gt 0 ]]; then col_def+="$ch"; else
              col_def="$(echo "$col_def" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
              [[ -n "$col_def" ]] && fields_buf+="$col_def"$'\n'
              col_def=""
            fi ;;
      $'\n'|' ') if [[ -z "$col_def" && $depth -eq 0 ]]; then continue; else col_def+="$ch"; fi ;;
      *)   col_def+="$ch" ;;
    esac
  done
  col_def="$(echo "$col_def" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -n "$col_def" ]] && fields_buf+="$col_def"$'\n'

  IFS="$IFS_OLD"

  # Iterate over fields_buf line by line
  while IFS= read -r col_def; do
    col_def="$(echo "$col_def" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$col_def" ]] && continue

    local col_name col_type
    col_name="$(echo "$col_def" | awk '{print $1}' | tr -d '"')"
    col_type="$(echo "$col_def" | awk '{print $2}' | tr -d '"')"
    [[ -z "$col_name" || -z "$col_type" ]] && continue

    local nullable="true"
    if echo "$col_def" | grep -qi "NOT NULL\|PRIMARY KEY"; then
      nullable="false"
    fi

    local is_pk=false
    if echo "$col_def" | grep -qi "PRIMARY KEY"; then
      is_pk=true
      nullable="false"
    fi

    local has_default=""
    if echo "$col_def" | grep -qi "DEFAULT"; then
      has_default="$(echo "$col_def" | sed -n 's/.*DEFAULT[[:space:]]\+//Ip' | head -1)"
      has_default="${has_default%%[,)[:space:]]*}"
    fi

    local go_name go_type
    go_name="$(echo "$col_name" | awk 'BEGIN{FS="[_ ]";OFS="";ORS=""}{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}print}')"
    go_name="$(fix_go_name "$go_name")"
    go_type="$(sql_to_go_type "$col_type" "$nullable")"

    case "$go_type" in
      *uuid*|*UUID*) needs_uuid=true ;;
    esac
    case "$go_type" in
      *time.Time*) needs_time=true ;;
    esac
    case "$go_type" in
      *json.RawMessage*) needs_json=true ;;
    esac

    local bun_tag="$col_name"
    if [[ "$is_pk" == true ]]; then
      if [[ "$col_type" =~ [Uu][Uu][Ii][Dd] ]]; then
        bun_tag="$col_name,type:uuid,pk"
      else
        bun_tag="$col_name,pk"
      fi
    fi
    if [[ "$nullable" == "true" && "$is_pk" == false ]]; then
      bun_tag="$col_name,nullzero"
    fi
    if [[ -n "$has_default" ]]; then
      bun_tag="$bun_tag,default:$has_default"
    fi
    if [[ "$col_type" =~ [Jj][Ss][Oo][Nn][Bb]? ]]; then
      bun_tag="$bun_tag,type:jsonb"
    fi

    local json_tag="$col_name"
    if [[ "$nullable" == "true" ]]; then
      json_tag="$col_name,omitempty"
    fi

    if [[ "$col_name" == "is_deleted" || "$col_name" == "deleted_at" ]]; then
      continue
    fi

    _fields+="	${go_name} ${go_type} \`bun:\"${bun_tag}\" json:\"${json_tag}\"\`"$'\n'
  done <<< "$fields_buf"

  if [[ "$needs_time" == true ]]; then
    _imports+=$'\t"time"\n'
  fi
  if [[ "$needs_json" == true ]]; then
    _imports+=$'\t"encoding/json"\n'
  fi
  _imports+=$'\n'
  if [[ "$needs_uuid" == true ]]; then
    _imports+=$'\t"github.com/google/uuid"\n'
  fi
  _imports+=$'\t"github.com/uptrace/bun"'
}

# ── Generate entity ──────────────────────────────────────────────────────────
ENTITY_DIR="entity"
ENTITY_FILE="$ENTITY_DIR/${ENTITY_LOWER}.go"

if [[ -f "$ENTITY_FILE" && "$FORCE" != "--force" ]]; then
  warn "Skipped $ENTITY_FILE — already exists (use --force to overwrite)"
  exit 0
fi

mkdir -p "$ENTITY_DIR"
parse_sql_to_entity "$SQL_INPUT"

cat > "$ENTITY_FILE" <<GOEOF
package entity

import (
${_imports}
)

// ${ENTITY_NAME} represents a record in the ${TABLE_NAME} table.
type ${ENTITY_NAME} struct {
	bun.BaseModel \`bun:"table:${TABLE_NAME},alias:${ENTITY_LOWER}"\`

${_fields}}

// TableName returns the database table name.
func (${ENTITY_NAME}) TableName() string {
	return "${TABLE_NAME}"
}
GOEOF

info "Created $ENTITY_FILE"

echo ""

# ── Wire entity module into main go.mod ──────────────────────────────────────
if [[ -f "go.mod" ]]; then
	echo "=== Wiring entity module ==="

	# Add replace directive if not exists
	if ! grep -q "replace ${SERVICE_MODULE}/entity" go.mod; then
		go mod edit -require "${SERVICE_MODULE}/entity@v0.0.0"
		go mod edit -replace "${SERVICE_MODULE}/entity=./entity"
		info "Added entity module to go.mod"
	else
		warn "Entity module already wired in go.mod"
	fi

	# Run go mod tidy in entity directory
	if [[ -d "entity" && -f "entity/go.mod" ]]; then
		(cd entity && go mod tidy 2>/dev/null)
		info "Ran go mod tidy in entity/"
	fi

	echo ""
fi

# ── Auto-generate repository ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== Auto-generating repository ==="
"$SCRIPT_DIR/scaffold-repo.sh" "$ENTITY_NAME" $FORCE "$SERVICE_MODULE"

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Review entity fields, add relations and custom tags"
echo "  2. Update searchFields and preloadRelations in the repository"
echo "  3. Run: scaffold-usecase.sh ${ENTITY_NAME}"

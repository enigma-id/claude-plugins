#!/usr/bin/env bash
# scaffold-publisher.sh — Generate event publisher boilerplate
# Usage: ./scaffold-publisher.sh <ModuleName> [--force] [service_module]
#
# Generates:
#   - src/event/publisher/{module}.go (event struct + publish functions)
#
# Example:
#   ./scaffold-publisher.sh Order
#   ./scaffold-publisher.sh Payment --force

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ── Parse arguments ──────────────────────────────────────────────────────────
MODULE_NAME=""
FORCE=""
MODULE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f) FORCE="--force"; shift ;;
    -*) fail "Unknown flag: $1" ;;
    *)  if [[ -z "$MODULE_NAME" ]]; then
          MODULE_NAME="$1"
        else
          MODULE_ARG="$1"
        fi
        shift ;;
  esac
done

if [[ -z "$MODULE_NAME" ]]; then
  fail "Usage: $0 <ModuleName> [--force] [service_module]"
fi

# ── Resolve SERVICE_MODULE and SERVICE_NAME ─────────────────────────────────
if [[ -n "$MODULE_ARG" ]]; then
  SERVICE_MODULE="$MODULE_ARG"
  SERVICE_NAME="$(basename "$SERVICE_MODULE")"
elif [[ -f "go.mod" ]]; then
  detect_service_module
else
  fail "No go.mod found. Pass module path as argument: $0 Order github.com/enigma-id/svc-order"
fi

# ── Derive naming variants ───────────────────────────────────────────────────
MODULE_LOWER="$(echo "$MODULE_NAME" | sed 's/\([A-Z]\)/_\1/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_//')"

echo "=== Scaffold Publisher ==="
echo "  Module:  $MODULE_NAME"
echo "  Service: $SERVICE_MODULE"
echo ""

# ── Generate src/event/publisher/{module}.go ─────────────────────────────────
PUBLISHER_DIR="src/event/publisher"
PUBLISHER_FILE="$PUBLISHER_DIR/${MODULE_LOWER}.go"

if [[ -f "$PUBLISHER_FILE" && "$FORCE" != "--force" ]]; then
  warn "Skipped $PUBLISHER_FILE — already exists (use --force to overwrite)"
  exit 0
fi

mkdir -p "$PUBLISHER_DIR"

cat > "$PUBLISHER_FILE" <<GOEOF
package publisher

import (
	"context"
	"time"

	"github.com/logistics-id/engine/broker/rabbitmq"
	"$SERVICE_MODULE/entity"
)

// ${MODULE_NAME}Event is the event payload for ${MODULE_NAME} events.
type ${MODULE_NAME}Event struct {
	${MODULE_NAME} *entity.${MODULE_NAME}
	PublishedAt time.Time
}

// ${MODULE_NAME}Created publishes a ${MODULE_LOWER}.created event.
func ${MODULE_NAME}Created(ctx context.Context, m *entity.${MODULE_NAME}) {
	rabbitmq.Publish(ctx, "${MODULE_LOWER}.created", &${MODULE_NAME}Event{
		${MODULE_NAME}: m,
		PublishedAt: time.Now(),
	})
}

// ${MODULE_NAME}Updated publishes a ${MODULE_LOWER}.updated event.
func ${MODULE_NAME}Updated(ctx context.Context, m *entity.${MODULE_NAME}) {
	rabbitmq.Publish(ctx, "${MODULE_LOWER}.updated", &${MODULE_NAME}Event{
		${MODULE_NAME}: m,
		PublishedAt: time.Now(),
	})
}

// ${MODULE_NAME}Deleted publishes a ${MODULE_LOWER}.deleted event.
func ${MODULE_NAME}Deleted(ctx context.Context, m *entity.${MODULE_NAME}) {
	rabbitmq.Publish(ctx, "${MODULE_LOWER}.deleted", &${MODULE_NAME}Event{
		${MODULE_NAME}: m,
		PublishedAt: time.Now(),
	})
}

// =============================================================================
// Add custom event publishers below:
//
// Example — custom event:
// func ${MODULE_NAME}Approved(ctx context.Context, m *entity.${MODULE_NAME}) {
//     rabbitmq.Publish(ctx, "${MODULE_LOWER}.approved", &${MODULE_NAME}Event{
//         ${MODULE_NAME}: m,
//         PublishedAt: time.Now(),
//     })
// }
//
// =============================================================================
GOEOF

info "Created $PUBLISHER_FILE"

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Call publisher functions in usecase methods after state changes"
echo "  2. Add custom event publishers if needed"
echo "  3. Example usage in usecase:"
echo "     import \"$SERVICE_MODULE/src/event/publisher\""
echo "     publisher.${MODULE_NAME}Created(ctx, entity)"

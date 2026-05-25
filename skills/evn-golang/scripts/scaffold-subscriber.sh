#!/usr/bin/env bash
# scaffold-subscriber.sh — Generate event subscriber boilerplate
# Usage: ./scaffold-subscriber.sh <EventSource> <EntityName> [--force] [service_module]
#
# EventSource: The service that publishes the event (e.g., "order", "payment")
# EntityName: The entity being subscribed to (e.g., "Order", "Payment")
#
# Generates:
#   - src/event/subscriber/{event_source}.go (message struct + handler functions)
#   - Updates src/subscriber.go (registers handlers)
#
# Example:
#   ./scaffold-subscriber.sh order Order
#   ./scaffold-subscriber.sh payment Payment --force

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ── Parse arguments ──────────────────────────────────────────────────────────
EVENT_SOURCE=""
ENTITY_NAME=""
FORCE=""
MODULE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f) FORCE="--force"; shift ;;
    -*) fail "Unknown flag: $1" ;;
    *)  if [[ -z "$EVENT_SOURCE" ]]; then
          EVENT_SOURCE="$1"
        elif [[ -z "$ENTITY_NAME" ]]; then
          ENTITY_NAME="$1"
        else
          MODULE_ARG="$1"
        fi
        shift ;;
  esac
done

if [[ -z "$EVENT_SOURCE" || -z "$ENTITY_NAME" ]]; then
  fail "Usage: $0 <EventSource> <EntityName> [--force] [service_module]
Example: $0 order Order
         $0 payment Payment"
fi

# ── Resolve SERVICE_MODULE and SERVICE_NAME ─────────────────────────────────
if [[ -n "$MODULE_ARG" ]]; then
  SERVICE_MODULE="$MODULE_ARG"
  SERVICE_NAME="$(basename "$SERVICE_MODULE")"
elif [[ -f "go.mod" ]]; then
  detect_service_module
else
  fail "No go.mod found. Pass module path as argument: $0 order Order github.com/enigma-id/svc-tracking"
fi

# ── Derive naming variants ───────────────────────────────────────────────────
EVENT_SOURCE_LOWER="$(echo "$EVENT_SOURCE" | tr '[:upper:]' '[:lower:]')"
ENTITY_LOWER="$(echo "$ENTITY_NAME" | sed 's/\([A-Z]\)/_\1/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_//')"

echo "=== Scaffold Subscriber ==="
echo "  Event Source: $EVENT_SOURCE"
echo "  Entity:       $ENTITY_NAME"
echo "  Service:      $SERVICE_MODULE"
echo ""

# ── Generate src/event/subscriber/{event_source}.go ──────────────────────────
SUBSCRIBER_DIR="src/event/subscriber"
SUBSCRIBER_FILE="$SUBSCRIBER_DIR/${EVENT_SOURCE_LOWER}.go"

if [[ -f "$SUBSCRIBER_FILE" && "$FORCE" != "--force" ]]; then
  warn "Skipped $SUBSCRIBER_FILE — already exists (use --force to overwrite)"
else
  mkdir -p "$SUBSCRIBER_DIR"

  cat > "$SUBSCRIBER_FILE" <<GOEOF
package subscriber

import (
	"context"

	"$SERVICE_MODULE/src/usecase"

	entity${ENTITY_NAME} "github.com/logistics-id/svc-${EVENT_SOURCE_LOWER}/entity"
	amqp "github.com/rabbitmq/amqp091-go"
)

// ${ENTITY_NAME}Message wraps the ${ENTITY_NAME} entity from svc-${EVENT_SOURCE_LOWER}.
type ${ENTITY_NAME}Message struct {
	${ENTITY_NAME} *entity${ENTITY_NAME}.${ENTITY_NAME}
}

// Subscribe${ENTITY_NAME}Created handles ${EVENT_SOURCE_LOWER}.created events.
func Subscribe${ENTITY_NAME}Created(req *${ENTITY_NAME}Message, msg amqp.Delivery) error {
	uc := usecase.NewFactory().WithContext(context.Background())

	// TODO: Implement business logic in usecase
	// err := uc.SomeModule.Handle${ENTITY_NAME}Created(req.${ENTITY_NAME})
	err := error(nil) // Replace with actual usecase call

	return msg.Ack(err == nil)
}

// Subscribe${ENTITY_NAME}Updated handles ${EVENT_SOURCE_LOWER}.updated events.
func Subscribe${ENTITY_NAME}Updated(req *${ENTITY_NAME}Message, msg amqp.Delivery) error {
	uc := usecase.NewFactory().WithContext(context.Background())

	// TODO: Implement business logic in usecase
	// err := uc.SomeModule.Handle${ENTITY_NAME}Updated(req.${ENTITY_NAME})
	err := error(nil) // Replace with actual usecase call

	return msg.Ack(err == nil)
}

// Subscribe${ENTITY_NAME}Deleted handles ${EVENT_SOURCE_LOWER}.deleted events.
func Subscribe${ENTITY_NAME}Deleted(req *${ENTITY_NAME}Message, msg amqp.Delivery) error {
	uc := usecase.NewFactory().WithContext(context.Background())

	// TODO: Implement business logic in usecase
	// err := uc.SomeModule.Handle${ENTITY_NAME}Deleted(req.${ENTITY_NAME})
	err := error(nil) // Replace with actual usecase call

	return msg.Ack(err == nil)
}

// =============================================================================
// Add custom event subscribers below:
//
// Example — custom event:
// func Subscribe${ENTITY_NAME}Approved(req *${ENTITY_NAME}Message, msg amqp.Delivery) error {
//     uc := usecase.NewFactory().WithContext(context.Background())
//     err := uc.SomeModule.Handle${ENTITY_NAME}Approved(req.${ENTITY_NAME})
//     return msg.Ack(err == nil)
// }
//
// Error handling with requeue:
// func Subscribe${ENTITY_NAME}Process(req *${ENTITY_NAME}Message, msg amqp.Delivery) error {
//     uc := usecase.NewFactory().WithContext(context.Background())
//     err := uc.SomeModule.Process${ENTITY_NAME}(req.${ENTITY_NAME})
//     if err != nil {
//         // Requeue on failure (retry)
//         msg.Nack(false, true)
//         return err
//     }
//     return msg.Ack(false)
// }
//
// =============================================================================
GOEOF

  info "Created $SUBSCRIBER_FILE"
fi

# ── Update src/subscriber.go ─────────────────────────────────────────────────
SUBSCRIBER_REG_FILE="src/subscriber.go"

if [[ ! -f "$SUBSCRIBER_REG_FILE" ]]; then
  warn "src/subscriber.go not found — skipping registration"
else
  # Check if this event source is already registered
  if grep -q "Subscribe${ENTITY_NAME}Created" "$SUBSCRIBER_REG_FILE"; then
    warn "${ENTITY_NAME} events already registered in $SUBSCRIBER_REG_FILE"
  else
    # Add registration lines before closing brace
    sed -i.bak "/^func RegisterSubscriber/,/^}/ {
      /^}/ i\\
\\
	// svc-${EVENT_SOURCE_LOWER}\\
	rabbitmq.Subscribe(\"${EVENT_SOURCE_LOWER}.created\", subscriber.Subscribe${ENTITY_NAME}Created)\\
	rabbitmq.Subscribe(\"${EVENT_SOURCE_LOWER}.updated\", subscriber.Subscribe${ENTITY_NAME}Updated)\\
	rabbitmq.Subscribe(\"${EVENT_SOURCE_LOWER}.deleted\", subscriber.Subscribe${ENTITY_NAME}Deleted)
    }" "$SUBSCRIBER_REG_FILE"
    rm -f "${SUBSCRIBER_REG_FILE}.bak"
    info "Added ${ENTITY_NAME} event subscriptions to $SUBSCRIBER_REG_FILE"
  fi
fi

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Implement usecase methods to handle events"
echo "  2. Update entity import path if svc-${EVENT_SOURCE_LOWER} is not correct"
echo "  3. Add custom event subscribers if needed"
echo "  4. Test event flow with RabbitMQ"

#!/usr/bin/env bash
# scaffold-grpc.sh — Generate gRPC handler boilerplate from .proto file
# Usage: ./scaffold-grpc.sh <module_name> [--force] [service_module]
#
# Prerequisites:
#   - proto/{module}.proto must exist
#   - User must run protoc manually after scaffold
#
# Generates:
#   - proto/constant.go (ServiceName)
#   - proto/converter.go (entity ↔ proto converter stubs)
#   - src/handler/grpc/{module}.go (gRPC handler with UnimplementedServer)
#   - Updates src/handler.go (RegisterGrpcRoutes)
#
# Example:
#   ./scaffold-grpc.sh Order
#   cd proto && protoc --go_out=. --go-grpc_out=. order.proto

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
MODULE_PLURAL="$(pluralize "$MODULE_LOWER")"
PROTO_FILE="proto/${MODULE_LOWER}.proto"

echo "=== Scaffold gRPC Handler ==="
echo "  Module:  $MODULE_NAME"
echo "  Service: $SERVICE_MODULE"
echo "  Proto:   $PROTO_FILE"
echo ""

# ── Verify proto file exists ─────────────────────────────────────────────────
if [[ ! -f "$PROTO_FILE" ]]; then
  fail "Proto file not found: $PROTO_FILE. Create it first, then run this script."
fi

# ── Parse proto file for service name ────────────────────────────────────────
PROTO_SERVICE_NAME="$(grep -o 'service [A-Za-z0-9_]*' "$PROTO_FILE" | head -1 | awk '{print $2}')"
if [[ -z "$PROTO_SERVICE_NAME" ]]; then
  fail "Could not find 'service' definition in $PROTO_FILE"
fi

echo "  Proto Service: $PROTO_SERVICE_NAME"
echo ""

# ── Generate proto/constant.go ───────────────────────────────────────────────
CONSTANT_FILE="proto/constant.go"
if [[ -f "$CONSTANT_FILE" && "$FORCE" != "--force" ]]; then
  warn "Skipped $CONSTANT_FILE — already exists (use --force to overwrite)"
else
  mkdir -p proto
  cat > "$CONSTANT_FILE" <<GOEOF
package proto

const ServiceName string = "$SERVICE_NAME"
GOEOF
  info "Created $CONSTANT_FILE"
fi

# ── Generate proto/converter.go ──────────────────────────────────────────────
CONVERTER_FILE="proto/converter.go"
if [[ -f "$CONVERTER_FILE" && "$FORCE" != "--force" ]]; then
  warn "Skipped $CONVERTER_FILE — already exists (use --force to overwrite)"
else
  cat > "$CONVERTER_FILE" <<GOEOF
package proto

import (
	"$SERVICE_MODULE/entity"
)

// Convert${MODULE_NAME} converts entity.${MODULE_NAME} to proto.${MODULE_NAME}
func Convert${MODULE_NAME}(m *entity.${MODULE_NAME}) *${MODULE_NAME} {
	if m == nil {
		return nil
	}

	return &${MODULE_NAME}{
		Id: m.ID.String(),
		// TODO: Map entity fields to proto fields
		// Name: m.Name,
	}
}

// Convert${MODULE_NAME}ToEntity converts proto.${MODULE_NAME} to entity.${MODULE_NAME}
func Convert${MODULE_NAME}ToEntity(m *${MODULE_NAME}) (*entity.${MODULE_NAME}, error) {
	if m == nil {
		return nil, nil
	}

	// TODO: Parse ID and map proto fields to entity
	// id, err := uuid.Parse(m.Id)
	// if err != nil {
	//     return nil, err
	// }

	return &entity.${MODULE_NAME}{
		// ID: id,
		// Name: m.Name,
	}, nil
}
GOEOF
  info "Created $CONVERTER_FILE"
fi

# ── Generate src/handler/grpc/{module}.go ────────────────────────────────────
GRPC_HANDLER_DIR="src/handler/grpc"
GRPC_HANDLER_FILE="$GRPC_HANDLER_DIR/${MODULE_LOWER}.go"

if [[ -f "$GRPC_HANDLER_FILE" && "$FORCE" != "--force" ]]; then
  warn "Skipped $GRPC_HANDLER_FILE — already exists (use --force to overwrite)"
else
  mkdir -p "$GRPC_HANDLER_DIR"
  cat > "$GRPC_HANDLER_FILE" <<GOEOF
package grpc

import (
	"context"

	"$SERVICE_MODULE/proto"
	"$SERVICE_MODULE/src/usecase"
)

// handler is the gRPC server for ${MODULE_LOWER} service
type ${MODULE_LOWER}Handler struct {
	proto.Unimplemented${PROTO_SERVICE_NAME}Server
	uc *usecase.Factory
}

// Register${MODULE_NAME}Handler registers the gRPC handler for ${MODULE_NAME}
func Register${MODULE_NAME}Handler() proto.${PROTO_SERVICE_NAME}Server {
	return &${MODULE_LOWER}Handler{
		uc: usecase.NewFactory(),
	}
}

// =============================================================================
// Implement gRPC service methods below:
//
// Example — Show method:
// func (h *${MODULE_LOWER}Handler) Show(ctx context.Context, req *proto.ShowRequest) (*proto.${MODULE_NAME}Response, error) {
//     mx, err := h.uc.${MODULE_NAME}.WithContext(ctx).FindByID(req.Id)
//     if err != nil {
//         return nil, err
//     }
//     return &proto.${MODULE_NAME}Response{
//         ${MODULE_NAME}: proto.Convert${MODULE_NAME}(mx),
//     }, nil
// }
//
// =============================================================================
GOEOF
  info "Created $GRPC_HANDLER_FILE"
fi

# ── Update src/handler.go ────────────────────────────────────────────────────
HANDLER_FILE="src/handler.go"
if [[ ! -f "$HANDLER_FILE" ]]; then
  warn "src/handler.go not found — skipping RegisterGrpcRoutes update"
else
  # Check if RegisterGrpcRoutes exists
  if ! grep -q "func RegisterGrpcRoutes" "$HANDLER_FILE"; then
    # Add RegisterGrpcRoutes function
    cat >> "$HANDLER_FILE" <<GOEOF

// RegisterGrpcRoutes registers all gRPC service handlers.
// Called from: grpc.NewService(ctx, engine.Config.Name, src.RegisterGrpcRoutes)
func RegisterGrpcRoutes(srv *grpc.GrpcServer) {
	proto.Register${PROTO_SERVICE_NAME}Server(srv, grpc.Register${MODULE_NAME}Handler())
}
GOEOF
    info "Added RegisterGrpcRoutes to $HANDLER_FILE"
  else
    # Check if this module is already registered
    if grep -q "Register${MODULE_NAME}Handler" "$HANDLER_FILE"; then
      warn "$MODULE_NAME already registered in $HANDLER_FILE"
    else
      # Add registration line before closing brace
      sed -i.bak "/^func RegisterGrpcRoutes/,/^}/ {
        /^}/ i\\
	proto.Register${PROTO_SERVICE_NAME}Server(srv, grpc.Register${MODULE_NAME}Handler())
      }" "$HANDLER_FILE"
      rm -f "${HANDLER_FILE}.bak"
      info "Added $MODULE_NAME to RegisterGrpcRoutes in $HANDLER_FILE"
    fi
  fi
fi

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Fill in converter.go with actual field mappings"
echo "  2. Implement gRPC service methods in $GRPC_HANDLER_FILE"
echo "  3. Run protoc to generate .pb.go files:"
echo "     cd proto && protoc --go_out=. --go-grpc_out=. ${MODULE_LOWER}.proto"
echo "  4. Uncomment gRPC server in main.go if not already active"

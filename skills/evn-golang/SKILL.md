---
name: evn-golang
description: Go backend standards for EVN services - clean architecture, project structure, coding conventions, and scaffold tools
triggers:
  - golang
  - go backend
  - clean architecture
  - repository pattern
  - usecase
  - handler
  - scaffold
  - project structure
---

# EVN Go Backend Standards

Go backend coding standards, clean architecture patterns, and project structure for EVN microservices.

## Core Principles

1. **Clean Architecture** — Strict layer separation: Handler → Usecase → Repository → Database
2. **Scaffold First** — Generate skeleton code, then customize
3. **No Layer Skipping** — Every request flows through all layers
4. **Raw Errors** — Never wrap errors, return them as-is
5. **Type Safety** — Explicit types, no `interface{}` unless necessary

## Project Structure

```
svc-warehouse/                    # Service root
├── go.mod                        # Main module
├── main.go                       # Entry point
├── entity/                       # Separate Go module
│   ├── go.mod                    # entity module
│   ├── warehouse.go              # Entity definitions
│   └── delivery_plan.go
├── src/
│   ├── factory/
│   │   └── factory.go            # Dependency injection
│   ├── handler/
│   │   ├── handler.go            # Route registration
│   │   ├── warehouse/            # Module handlers
│   │   │   ├── create.go
│   │   │   ├── update.go
│   │   │   └── show.go
│   │   └── delivery_plan/
│   │       └── publish.go
│   ├── publisher/
│   │   └── warehouse.go          # RabbitMQ publishers
│   ├── repository/
│   │   ├── warehouse.go          # Data access layer
│   │   └── delivery_plan.go
│   ├── subscriber/
│   │   └── warehouse.go          # RabbitMQ subscribers
│   └── usecase/
│       ├── warehouse.go          # Business logic
│       └── delivery_plan.go
└── migrations/                   # Database migrations
    ├── 20260525_create_warehouses.up.sql
    └── 20260525_create_warehouses.down.sql
```

## Naming Conventions

### Files & Directories

- **snake_case** — All files and directories
- **Singular names** — `warehouse.go`, not `warehouses.go`
- **Module directories** — `handler/warehouse/`, `handler/delivery_plan/`

### Go Code

- **PascalCase** — Exported types, functions, constants
- **camelCase** — Unexported variables, functions
- **ALL_CAPS** — Constants (rare, prefer PascalCase)

```go
// ✅ Correct
type Warehouse struct {}
func NewWarehouse() *Warehouse {}
const MaxRetries = 3

// ❌ Wrong
type warehouse struct {}  // Should be exported
func new_warehouse() {}   // Should be camelCase
const max_retries = 3     // Should be PascalCase
```

### Packages

- **Short, lowercase** — `handler`, `usecase`, `repository`
- **No underscores** — `deliveryplan`, not `delivery_plan`
- **Descriptive** — Package name should describe its purpose

## Two Naming Domains

All code generation is driven by two naming domains:

| Domain | Source | Example | Used By |
|---|---|---|---|
| **ENTITY_NAME** | SQL table name (PascalCase) | `Warehouse` | `entity/`, `repository/` |
| **MODULE_NAME** | Business feature (PascalCase) | `DeliveryPlan` | `usecase/`, `handler/`, `factory.go` |

**Key distinction:**
- **Entity** = database table (data layer)
- **Module** = business feature (business layer)

A module may use multiple entities. Example: `DeliveryPlan` module uses `DeliveryPlan`, `DeliveryPlanItem`, and `Item` entities.

## Clean Architecture Layers

### Layer Flow

```
HTTP Request
    ↓
Handler (transport layer)
    ↓
Request Struct (validation + transformation)
    ↓
Usecase (business logic)
    ↓
Repository (data access)
    ↓
Database
```

### Layer Rules

**Rule 1 — Never skip layers**
Every request must flow through all layers. No shortcuts.

```go
// ❌ Wrong — Handler calling repository directly
func (h *Handler) Create(ctx *rest.Context) error {
    warehouse, err := h.uc.Warehouse.Repo.FindByID(id)
    // ...
}

// ✅ Correct — Handler calls usecase, usecase calls repository
func (h *Handler) Create(ctx *rest.Context) error {
    warehouse, err := h.uc.Warehouse.Show(id)
    // ...
}
```

**Rule 2 — Repository only accessible by usecase**
Handler and request structs MUST NOT access `.Repo` directly.

**Rule 3 — Return raw errors, never wrap**
The engine extracts error messages from raw errors. Wrapping loses the message.

```go
// ✅ Correct
return nil, err

// ❌ Wrong — wrapping loses the message
return nil, fmt.Errorf("failed to create: %w", err)
```

**Rule 4 — Publish events async with captured context**

```go
// ✅ Correct — capture context before goroutine
ctx := u.ctx
go publisher.WarehouseCreated(ctx, req)

// ❌ Wrong — loses context reference
go publisher.WarehouseCreated(u.ctx, req)
```

## Scaffold Tools

### Location

Scripts are in `skills/evn-golang/scripts/`:
- `scaffold-init.sh` — Project skeleton
- `scaffold-entity.sh` — Entity + repository (chains to scaffold-repo.sh)
- `scaffold-repo.sh` — Repository (called by scaffold-entity.sh)
- `scaffold-usecase.sh` — Usecase
- `scaffold-factory.sh` — Factory wiring
- `scaffold-handler.sh` — Handler + request files
- `scaffold-grpc.sh` — gRPC handler + proto boilerplate
- `scaffold-publisher.sh` — Event publisher
- `scaffold-subscriber.sh` — Event subscriber

### Workflow

**Step 0 — Determine project type**

Ask the user:
- **Existing project?** — `go.mod` exists, proceed to Step 1
- **New project?** — Ask for Go module path (e.g., `github.com/enigma-id/svc-myapi`)

For new projects:
```bash
mkdir -p ~/Works/Enigma/svc-myapi
cd ~/Works/Enigma/svc-myapi
go mod init github.com/enigma-id/svc-myapi
```

**Step 1 — Initialize project**

```bash
SCRIPTS=~/Works/Enigma/claude-plugins/skills/evn-golang/scripts
cd ~/Works/Enigma/svc-myapi

# Generate project skeleton
$SCRIPTS/scaffold-init.sh

# Initialize entity module
cd entity && go mod init github.com/enigma-id/svc-myapi/entity && cd ..

# Wire entity module (required for subdirectory modules)
go mod edit -require github.com/enigma-id/svc-myapi/entity@v0.0.0
go mod edit -replace github.com/enigma-id/svc-myapi/entity=./entity
```

**Step 2 — Generate entity + repository**

```bash
# From SQL CREATE TABLE statement
echo "CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);" | $SCRIPTS/scaffold-entity.sh --from-stdin

# This generates:
# - entity/warehouse.go
# - src/repository/warehouse.go
```

**Step 3 — Generate usecase**

```bash
$SCRIPTS/scaffold-usecase.sh Warehouse

# Generates: src/usecase/warehouse.go
```

**Step 4 — Wire into factory**

```bash
$SCRIPTS/scaffold-factory.sh Warehouse

# Updates: src/factory/factory.go
```

**Step 5 — Generate handler**

```bash
$SCRIPTS/scaffold-handler.sh Warehouse

# Generates:
# - src/handler/warehouse/create.go
# - src/handler/warehouse/update.go
# - src/handler/warehouse/show.go
# - src/handler/warehouse/list.go
# - src/handler/warehouse/delete.go
# Updates: src/handler/handler.go (route registration)
```

**Step 6 — Resolve dependencies**

```bash
go mod tidy && go build ./...
```

### Force Overwrite

Use `-f` flag to overwrite existing files:

```bash
$SCRIPTS/scaffold-entity.sh --from-stdin -f
$SCRIPTS/scaffold-usecase.sh Warehouse -f
```

## Code Patterns

### Entity (Data Layer)

```go
package entity

import (
    "github.com/uptrace/bun"
    "github.com/google/uuid"
    "time"
)

type Warehouse struct {
    bun.BaseModel `bun:"table:warehouse,alias:w"`

    ID        uuid.UUID `bun:"id,pk,type:uuid,default:uuid_generate_v4()"`
    Name      string    `bun:"name,notnull"`
    Address   string    `bun:"address,null"`
    IsActive  bool      `bun:"is_active,notnull,default:true"`
    CreatedAt time.Time `bun:"created_at,notnull"`
    UpdatedAt time.Time `bun:"updated_at,notnull"`
}
```

**Bun tags:**
- `pk` — Primary key
- `notnull` — Required field
- `null` — Nullable field
- `type:uuid` — UUID type
- `default:uuid_generate_v4()` — Auto-generate UUID
- `alias:w` — Table alias for queries

**Nullable fields:**
Use pointer types for nullable fields: `*float64`, `*uuid.UUID`, `*bool`

### Repository (Data Access Layer)

```go
package repository

import (
    "github.com/logistics-id/engine/ds/postgres"
    "github.com/enigma-id/svc-myapi/entity"
)

type WarehouseRepository struct {
    *postgres.BaseRepository[entity.Warehouse]
}

func NewWarehouseRepository(db *bun.DB) *WarehouseRepository {
    return &WarehouseRepository{
        BaseRepository: postgres.NewBaseRepository[entity.Warehouse](
            db,
            "warehouse",                       // table name
            []string{"w.name", "w.address"},   // searchable fields
            []string{},                        // default relations
            false,                             // soft delete disabled
        ),
    }
}

// Override WithContext for method chaining
func (r *WarehouseRepository) WithContext(ctx context.Context) *WarehouseRepository {
    return &WarehouseRepository{
        BaseRepository: r.BaseRepository.WithCtx(ctx),
    }
}

// Custom query methods
func (r *WarehouseRepository) FindByName(ctx context.Context, name string) (*entity.Warehouse, error) {
    return r.WithContext(ctx).FindOne(func(q *bun.SelectQuery) *bun.SelectQuery {
        return q.Where("name = ?", name)
    })
}
```

### Usecase (Business Logic Layer)

```go
package usecase

import (
    "context"
    "github.com/enigma-id/svc-myapi/src/repository"
    "github.com/enigma-id/svc-myapi/entity"
)

type WarehouseUsecase struct {
    ctx  context.Context
    Repo *repository.WarehouseRepository
}

func NewWarehouseUsecase(ctx context.Context, repo *repository.WarehouseRepository) *WarehouseUsecase {
    return &WarehouseUsecase{
        ctx:  ctx,
        Repo: repo,
    }
}

func (u *WarehouseUsecase) Create(req *entity.Warehouse) (*entity.Warehouse, error) {
    if err := u.Repo.WithContext(u.ctx).Insert(req); err != nil {
        return nil, err
    }
    return req, nil
}

func (u *WarehouseUsecase) Show(id string) (*entity.Warehouse, error) {
    return u.Repo.WithContext(u.ctx).FindByID(id)
}

func (u *WarehouseUsecase) Update(id string, req *entity.Warehouse) (*entity.Warehouse, error) {
    existing, err := u.Repo.WithContext(u.ctx).FindByID(id)
    if err != nil {
        return nil, err
    }

    existing.Name = req.Name
    existing.Address = req.Address

    if err := u.Repo.WithContext(u.ctx).Update(existing); err != nil {
        return nil, err
    }

    return existing, nil
}
```

### Handler (Transport Layer)

```go
package warehouse

import (
    "github.com/logistics-id/engine/transport/rest"
    "github.com/enigma-id/svc-myapi/src/factory"
)

type CreateWarehouseHandler struct {
    uc *factory.Usecase
}

func NewCreateWarehouseHandler(uc *factory.Usecase) *CreateWarehouseHandler {
    return &CreateWarehouseHandler{uc: uc}
}

func (h *CreateWarehouseHandler) Handle(ctx *rest.Context) error {
    var req CreateWarehouseRequest
    if err := ctx.Bind(&req); err != nil {
        return ctx.Respond(nil, err)
    }

    result, err := req.execute(ctx.Request.Context(), h.uc)
    return ctx.Respond(result, err)
}
```

**Request Validation Flow:**

`ctx.Bind()` automatically handles validation via the `validate.Request` interface:

1. **Bind** — Decodes JSON body / query params / path params into the request struct
2. **Validate** — Calls `req.Validate()` if the struct implements `validate.Request`
3. **Messages** — Applies custom error messages from `req.Messages()`
4. **Return** — Returns validation errors or nil if valid

**Source:** `github.com/logistics-id/engine/transport/rest/context.go`

```go
// Inside ctx.Bind():
if err := c.Validate(v); !err.Valid {
    return err
}

// Inside ctx.Validate():
if vr, ok := obj.(validate.Request); ok {
    resp = c.validator.Request(vr)  // Calls vr.Validate() and vr.Messages()
}
```

**Key Point:** You never call `Validate()` explicitly in handler code. `ctx.Bind()` does it automatically.
```

### Request Struct (5 Required Methods)

```go
package warehouse

import (
    "context"
    "github.com/logistics-id/engine/validate"
    "github.com/enigma-id/svc-myapi/src/factory"
    "github.com/enigma-id/svc-myapi/entity"
)

type CreateWarehouseRequest struct {
    Name    string `json:"name" valid:"required"`
    Address string `json:"address" valid:"required"`
}

// 1. Validate — validation rules
func (r *CreateWarehouseRequest) Validate() *validate.Response {
    return validate.Struct(r)
}

// 2. Messages — custom error messages
func (r *CreateWarehouseRequest) Messages() map[string]string {
    return map[string]string{
        "required": "The %s field is required",
    }
}

// 3. toEntity — transform to entity
func (r *CreateWarehouseRequest) toEntity() *entity.Warehouse {
    return &entity.Warehouse{
        Name:    r.Name,
        Address: r.Address,
    }
}

// 4. execute — business logic
func (r *CreateWarehouseRequest) execute(ctx context.Context, uc *factory.Usecase) (*entity.Warehouse, error) {
    return uc.Warehouse.Create(r.toEntity())
}

// 5. with — dependency injection (optional, for complex cases)
func (r *CreateWarehouseRequest) with(uc *factory.Usecase) *CreateWarehouseRequest {
    return r
}
```

### Factory (Dependency Injection)

```go
package factory

import (
    "context"
    "github.com/uptrace/bun"
    "github.com/enigma-id/svc-myapi/src/repository"
    "github.com/enigma-id/svc-myapi/src/usecase"
)

type Usecase struct {
    Warehouse *usecase.WarehouseUsecase
}

func NewUsecase(ctx context.Context, db *bun.DB) *Usecase {
    // Repositories
    warehouseRepo := repository.NewWarehouseRepository(db)

    // Usecases
    return &Usecase{
        Warehouse: usecase.NewWarehouseUsecase(ctx, warehouseRepo),
    }
}
```

## Validation

### Validation Tags

| Tag | Description | Example |
|---|---|---|
| `required` | Field must not be empty | `valid:"required"` |
| `email` | Valid email format | `valid:"email"` |
| `uuid` | Valid UUID format | `valid:"uuid"` |
| `min:n` | Minimum value/length | `valid:"min:3"` |
| `max:n` | Maximum value/length | `valid:"max:100"` |
| `gte:n` | Greater than or equal | `valid:"gte:0"` |
| `lte:n` | Less than or equal | `valid:"lte:100"` |
| `oneof:A;B;C` | Value must be in list | `valid:"oneof:admin;user"` |
| `password` | Password strength | `valid:"password"` |
| `phone` | Phone number format | `valid:"phone"` |
| `alphanum` | Alphanumeric only | `valid:"alphanum"` |
| `numeric` | Numeric only | `valid:"numeric"` |

### Custom Validation

```go
func (r *CreateWarehouseRequest) Validate() *validate.Response {
    // Struct validation
    if resp := validate.Struct(r); resp != nil {
        return resp
    }

    // Custom validation
    if r.Latitude != nil && (*r.Latitude < -90 || *r.Latitude > 90) {
        return &validate.Response{
            Errors: map[string][]string{
                "latitude": {"Latitude must be between -90 and 90"},
            },
        }
    }

    return nil
}
```

## Error Handling

### Return Raw Errors

```go
// ✅ Correct
warehouse, err := u.Repo.WithContext(u.ctx).FindByID(id)
if err != nil {
    return nil, err
}

// ❌ Wrong — wrapping loses error message
if err != nil {
    return nil, fmt.Errorf("failed to find warehouse: %w", err)
}
```

### Custom Errors

```go
import "errors"

var (
    ErrWarehouseNotFound = errors.New("warehouse not found")
    ErrInvalidCoordinates = errors.New("invalid coordinates")
)

func (u *WarehouseUsecase) Show(id string) (*entity.Warehouse, error) {
    warehouse, err := u.Repo.WithContext(u.ctx).FindByID(id)
    if err != nil {
        return nil, ErrWarehouseNotFound
    }
    return warehouse, nil
}
```

## Event Publishing

### Publisher Pattern

```go
package publisher

import (
    "context"
    "github.com/logistics-id/engine/broker/rabbitmq"
)

type WarehouseCreatedPayload struct {
    ID      string `json:"id"`
    Name    string `json:"name"`
    Address string `json:"address"`
}

func WarehouseCreated(ctx context.Context, payload WarehouseCreatedPayload) error {
    return rabbitmq.Publish(ctx, "warehouse.created", payload)
}
```

### Event Naming

Use **dot notation**: `noun.verb`

```
✅ Correct:
- warehouse.created
- warehouse.updated
- delivery.plan.published

❌ Wrong:
- warehouse:created  (colon separator)
- WarehouseCreated   (PascalCase)
- warehouse_created  (underscore)
```

### Async Publishing

```go
func (r *CreateWarehouseRequest) execute(ctx context.Context, uc *factory.Usecase) (*entity.Warehouse, error) {
    warehouse, err := uc.Warehouse.Create(r.toEntity())
    if err != nil {
        return nil, err
    }

    // Publish event async (capture context first)
    capturedCtx := ctx
    go publisher.WarehouseCreated(capturedCtx, publisher.WarehouseCreatedPayload{
        ID:      warehouse.ID.String(),
        Name:    warehouse.Name,
        Address: warehouse.Address,
    })

    return warehouse, nil
}
```

## Testing

### Repository Tests

```go
package repository_test

import (
    "context"
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/enigma-id/svc-myapi/src/repository"
    "github.com/enigma-id/svc-myapi/entity"
)

func TestWarehouseRepository_Create(t *testing.T) {
    // Setup test database
    db := setupTestDB(t)
    repo := repository.NewWarehouseRepository(db)
    ctx := context.Background()

    // Test data
    warehouse := &entity.Warehouse{
        Name:    "Test Warehouse",
        Address: "123 Test St",
    }

    // Execute
    err := repo.WithContext(ctx).Insert(warehouse)

    // Assert
    assert.NoError(t, err)
    assert.NotEmpty(t, warehouse.ID)
}
```

### Usecase Tests

```go
package usecase_test

import (
    "context"
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
)

type MockWarehouseRepository struct {
    mock.Mock
}

func (m *MockWarehouseRepository) Insert(w *entity.Warehouse) error {
    args := m.Called(w)
    return args.Error(0)
}

func TestWarehouseUsecase_Create(t *testing.T) {
    // Setup
    mockRepo := new(MockWarehouseRepository)
    uc := usecase.NewWarehouseUsecase(context.Background(), mockRepo)

    warehouse := &entity.Warehouse{Name: "Test"}
    mockRepo.On("Insert", warehouse).Return(nil)

    // Execute
    result, err := uc.Create(warehouse)

    // Assert
    assert.NoError(t, err)
    assert.Equal(t, "Test", result.Name)
    mockRepo.AssertExpectations(t)
}
```

## Best Practices

### 1. Scaffold First, Customize Later

Always generate skeleton code with scaffold scripts, then customize.

### 2. Use Pointer Types for Nullable Fields

```go
// ✅ Correct
Latitude *float64 `bun:"lat,null"`

// ❌ Wrong — will panic on zero values
Latitude float64 `bun:"lat,null"`
```

### 3. Keep Usecases Thin

Business logic should be simple. Complex logic goes in domain services.

### 4. Use Transactions for Multiple Operations

```go
err := repo.RunInTx(ctx, func(ctx context.Context, tx bun.Tx) error {
    // Multiple operations...
    return nil
})
```

### 5. Always Run `go mod tidy`

After scaffolding or adding dependencies:

```bash
go mod tidy && go build ./...
```

### 6. Use Context Everywhere

```go
// ✅ Correct
repo.WithContext(ctx).FindByID(id)

// ❌ Wrong
repo.FindByID(id)
```

### 7. Validate at the Boundary

Validate input in request structs, not in usecases or repositories.

## gRPC & Proto

### Proto Module Structure

Proto definitions live in a separate Go module:

```
svc-order/
├── go.mod                    # Main service module
├── proto/
│   ├── go.mod                # Separate proto module
│   ├── order.proto           # Proto definition (manual)
│   ├── order.pb.go           # Generated by protoc
│   ├── order_grpc.pb.go      # Generated by protoc
│   ├── constant.go           # ServiceName constant
│   └── converter.go          # Entity ↔ Proto converters
└── src/handler/grpc/
    └── order.go              # gRPC handler implementation
```

### Proto File Conventions

```protobuf
syntax = "proto3";

package order;
option go_package = "github.com/enigma-id/svc-order/proto;proto";

message Order {
  string id = 1;
  string code = 2;
  string name = 3;
  double total_charges = 4;
}

message ShowRequest {
  string id = 1;
}

message OrderResponse {
  Order order = 1;
}

service OrderService {
  rpc Show(ShowRequest) returns (OrderResponse);
  rpc List(ListRequest) returns (ListResponse);
}
```

### Scaffold gRPC Handler

**Prerequisites:**
1. Write `.proto` file manually in `proto/` directory
2. Define service and RPC methods

**Generate boilerplate:**

```bash
SCRIPTS=~/Works/Enigma/claude-plugins/skills/evn-golang/scripts
cd ~/Works/Enigma/svc-myapi

# Generate gRPC handler boilerplate
$SCRIPTS/scaffold-grpc.sh Order

# This generates:
# - proto/constant.go (ServiceName)
# - proto/converter.go (entity ↔ proto stubs)
# - src/handler/grpc/order.go (handler skeleton)
# - Updates src/handler.go (RegisterGrpcRoutes)
```

**Generate proto code:**

```bash
cd proto
protoc --go_out=. --go-grpc_out=. order.proto
```

### Converter Pattern

```go
package proto

import (
    "github.com/enigma-id/svc-order/entity"
    "github.com/google/uuid"
)

// ConvertOrder converts entity.Order to proto.Order
func ConvertOrder(m *entity.Order) *Order {
    if m == nil {
        return nil
    }

    return &Order{
        Id:           m.ID.String(),
        Code:         m.Code,
        Name:         m.Name,
        TotalCharges: m.TotalCharges,
    }
}

// ConvertOrderToEntity converts proto.Order to entity.Order
func ConvertOrderToEntity(m *Order) (*entity.Order, error) {
    if m == nil {
        return nil, nil
    }

    id, err := uuid.Parse(m.Id)
    if err != nil {
        return nil, err
    }

    return &entity.Order{
        ID:           id,
        Code:         m.Code,
        Name:         m.Name,
        TotalCharges: m.TotalCharges,
    }, nil
}
```

### gRPC Handler Implementation

```go
package grpc

import (
    "context"

    "github.com/enigma-id/svc-order/proto"
    "github.com/enigma-id/svc-order/src/usecase"
)

type orderHandler struct {
    proto.UnimplementedOrderServiceServer
    uc *usecase.Factory
}

func RegisterOrderHandler() proto.OrderServiceServer {
    return &orderHandler{
        uc: usecase.NewFactory(),
    }
}

// Show implements OrderService.Show
func (h *orderHandler) Show(ctx context.Context, req *proto.ShowRequest) (*proto.OrderResponse, error) {
    mx, err := h.uc.Order.WithContext(ctx).FindByID(req.Id)
    if err != nil {
        return nil, err
    }

    return &proto.OrderResponse{
        Order: proto.ConvertOrder(mx),
    }, nil
}
```

### Service Registration

In `src/handler.go`:

```go
package src

import (
    "github.com/logistics-id/engine/transport/grpc"
    "github.com/enigma-id/svc-order/proto"
    grpcHandler "github.com/enigma-id/svc-order/src/handler/grpc"
)

// RegisterGrpcRoutes registers all gRPC service handlers.
func RegisterGrpcRoutes(srv *grpc.GrpcServer) {
    proto.RegisterOrderServiceServer(srv, grpcHandler.RegisterOrderHandler())
}
```

In `main.go`, ensure gRPC server is active:

```go
// Start gRPC server
transportGRPC := grpc.NewService(&grpc.Config{
    ServiceName:       engine.Config.Name,
    Namespace:         os.Getenv("PLATFORM"),
    Address:           os.Getenv("GRPC_SERVER"),
    AdvertisedAddress: os.Getenv("GRPC_ADDRESS"),
}, engine.Logger, src.RegisterGrpcRoutes)

go transportGRPC.Start(ctx)
defer transportGRPC.Shutdown(ctx)
```

### Proto Code Generation

Install protoc compiler and Go plugins:

```bash
# Install protoc
brew install protobuf  # macOS
# or download from https://github.com/protocolbuffers/protobuf/releases

# Install Go plugins
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

Generate code:

```bash
cd proto
protoc --go_out=. --go-grpc_out=. *.proto
```

### gRPC Best Practices

1. **Separate Proto Module** — Keep proto definitions isolated with their own `go.mod`
2. **Manual Proto Design** — Write `.proto` files manually, don't auto-generate from entities
3. **Bidirectional Converters** — Always implement both `Convert*()` and `Convert*ToEntity()`
4. **Nil Checks** — Always check for nil in converters
5. **Error Propagation** — Return gRPC errors directly, don't wrap
6. **Context Propagation** — Always pass context to usecase methods

## Event-Driven Architecture

### Publisher Pattern

Publishers emit events when entity state changes. Follow the svc-payment pattern:

**Structure:**
```
src/event/publisher/
└── order.go              # Event struct + publish functions
```

**Implementation:**

```go
package publisher

import (
    "context"
    "time"

    "github.com/logistics-id/engine/broker/rabbitmq"
    "github.com/enigma-id/svc-order/entity"
)

// OrderEvent is the event payload for Order events.
type OrderEvent struct {
    Order       *entity.Order
    PublishedAt time.Time
}

// OrderCreated publishes an order.created event.
func OrderCreated(ctx context.Context, m *entity.Order) {
    rabbitmq.Publish(ctx, "order.created", &OrderEvent{
        Order:       m,
        PublishedAt: time.Now(),
    })
}

// OrderUpdated publishes an order.updated event.
func OrderUpdated(ctx context.Context, m *entity.Order) {
    rabbitmq.Publish(ctx, "order.updated", &OrderEvent{
        Order:       m,
        PublishedAt: time.Now(),
    })
}

// OrderDeleted publishes an order.deleted event.
func OrderDeleted(ctx context.Context, m *entity.Order) {
    rabbitmq.Publish(ctx, "order.deleted", &OrderEvent{
        Order:       m,
        PublishedAt: time.Now(),
    })
}
```

**Usage in Usecase:**

```go
package usecase

import (
    "github.com/enigma-id/svc-order/src/event/publisher"
)

func (u *OrderUsecase) Create(req *entity.Order) error {
    if err := u.repo.Insert(req); err != nil {
        return err
    }

    // Publish event after successful state change
    publisher.OrderCreated(u.ctx, req)

    return nil
}
```

**Scaffold Publisher:**

```bash
SCRIPTS=~/Works/Enigma/claude-plugins/skills/evn-golang/scripts
cd ~/Works/Enigma/svc-order

# Generate publisher boilerplate
$SCRIPTS/scaffold-publisher.sh Order

# This generates:
# - src/event/publisher/order.go (event struct + Created/Updated/Deleted functions)
```

### Subscriber Pattern

Subscribers listen to events from other services. Follow the svc-tracking pattern:

**Structure:**
```
src/event/subscriber/
└── order.go              # Message struct + handler functions
```

**Implementation:**

```go
package subscriber

import (
    "context"

    "github.com/enigma-id/svc-tracking/src/usecase"

    entityOrder "github.com/logistics-id/svc-order/entity"
    amqp "github.com/rabbitmq/amqp091-go"
)

// OrderMessage wraps the Order entity from svc-order.
type OrderMessage struct {
    Order *entityOrder.Order
}

// SubscribeOrderCreated handles order.created events.
func SubscribeOrderCreated(req *OrderMessage, msg amqp.Delivery) error {
    uc := usecase.NewFactory().WithContext(context.Background())

    err := uc.Tracking.OrderCreated(req.Order)

    return msg.Ack(err == nil)
}

// SubscribeOrderUpdated handles order.updated events.
func SubscribeOrderUpdated(req *OrderMessage, msg amqp.Delivery) error {
    uc := usecase.NewFactory().WithContext(context.Background())

    err := uc.Tracking.OrderUpdated(req.Order)

    return msg.Ack(err == nil)
}
```

**Error Handling with Requeue:**

```go
func SubscribeOrderProcess(req *OrderMessage, msg amqp.Delivery) error {
    uc := usecase.NewFactory().WithContext(context.Background())

    err := uc.Tracking.ProcessOrder(req.Order)
    if err != nil {
        // Requeue on failure (retry)
        msg.Nack(false, true)
        return err
    }

    return msg.Ack(false)
}
```

**Registration in src/subscriber.go:**

```go
package src

import (
    "github.com/logistics-id/svc-tracking/src/event/subscriber"
    "github.com/logistics-id/engine/broker/rabbitmq"
)

func RegisterSubscriber() {
    // svc-order events
    rabbitmq.Subscribe("order.created", subscriber.SubscribeOrderCreated)
    rabbitmq.Subscribe("order.updated", subscriber.SubscribeOrderUpdated)
    rabbitmq.Subscribe("order.deleted", subscriber.SubscribeOrderDeleted)

    // svc-payment events
    rabbitmq.Subscribe("payment.paided", subscriber.SubscribePaymentPaided)
    rabbitmq.Subscribe("payment.expired", subscriber.SubscribePaymentExpired)
}
```

**Scaffold Subscriber:**

```bash
SCRIPTS=~/Works/Enigma/claude-plugins/skills/evn-golang/scripts
cd ~/Works/Enigma/svc-tracking

# Generate subscriber boilerplate
$SCRIPTS/scaffold-subscriber.sh order Order

# This generates:
# - src/event/subscriber/order.go (message struct + handler functions)
# - Updates src/subscriber.go (registers handlers)
```

### Event Naming Conventions

| Pattern | Example | Description |
|---|---|---|
| `{entity}.{action}` | `order.created` | Standard CRUD events |
| `{entity}.{status}` | `payment.paided` | Status change events |
| `{entity}.{entity}.{action}` | `order.route.departed` | Nested entity events |

**Rules:**
- Lowercase, dot-separated
- Past tense for actions: `created`, `updated`, `deleted`, `paided`
- Present tense for status: `active`, `expired`

### Event-Driven Best Practices

1. **Publish After Success** — Only publish events after database commit succeeds
2. **Delegate to Usecase** — Subscribers should delegate business logic to usecase methods, not implement inline
3. **Idempotency** — Design handlers to be idempotent (safe to retry)
4. **Ack on Success** — Use `msg.Ack(err == nil)` for simple cases
5. **Nack with Requeue** — Use `msg.Nack(false, true)` for retriable failures
6. **Context Propagation** — Always create fresh context in subscribers: `context.Background()`
7. **External Entities** — Import external entities with alias: `entityOrder "github.com/logistics-id/svc-order/entity"`
8. **Event Versioning** — Include version in event name for breaking changes: `order.v2.created`

### When to Use Events

**Use Events For:**
- Cross-service notifications (order created → send invoice)
- Async workflows (payment received → fulfill order)
- Audit trails (track state changes)
- Fan-out patterns (one event, multiple subscribers)

**Don't Use Events For:**
- Synchronous validation (use gRPC)
- Request-response patterns (use REST/gRPC)
- Transactions across services (use saga pattern with compensation)

## Checklist for New Features

### REST API Feature
- [ ] Scaffold entity + repository
- [ ] Scaffold usecase
- [ ] Wire into factory
- [ ] Scaffold handler + request files
- [ ] Add validation rules to request struct
- [ ] Implement business logic in usecase
- [ ] Add event publishing (if needed)
- [ ] Write tests
- [ ] Run `go mod tidy && go build ./...`

### gRPC Service Feature
- [ ] Write `.proto` file with service definition
- [ ] Scaffold gRPC handler with `scaffold-grpc.sh`
- [ ] Generate proto code: `cd proto && protoc --go_out=. --go-grpc_out=. *.proto`
- [ ] Implement converter functions in `proto/converter.go`
- [ ] Implement RPC methods in `src/handler/grpc/{module}.go`
- [ ] Ensure gRPC server is active in `main.go`
- [ ] Wire proto module in main `go.mod` if needed
- [ ] Write tests
- [ ] Run `go mod tidy && go build ./...`

### Event Publisher Feature
- [ ] Scaffold publisher with `scaffold-publisher.sh`
- [ ] Call publisher functions in usecase after state changes
- [ ] Add custom event types if needed
- [ ] Test event publishing with RabbitMQ
- [ ] Document event schema for consumers

### Event Subscriber Feature
- [ ] Scaffold subscriber with `scaffold-subscriber.sh`
- [ ] Implement usecase methods to handle events
- [ ] Update external entity import paths if needed
- [ ] Add custom event handlers if needed
- [ ] Test event consumption with RabbitMQ
- [ ] Handle errors with proper Ack/Nack strategy
- [ ] Test endpoints manually

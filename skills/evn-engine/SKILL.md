---
name: evn-engine
description: Engine framework usage patterns for EVN microservices - lifecycle management, database integration, message brokers, and transport protocols
triggers:
  - engine
  - lifecycle
  - onstart
  - onstop
  - rabbitmq
  - bun orm
  - rest server
  - grpc
  - validation
  - session
  - jwt
---

# EVN Engine Framework

Usage patterns for the `logistics-id/engine` framework — lifecycle management, database integration, message brokers, and transport protocols for EVN microservices.

## Framework Overview

Engine is a production-ready Go framework for rapidly building microservices. It provides:

- **Lifecycle Management** — `OnStart`, `OnStop`, `Run` hooks for graceful startup/shutdown
- **Database Integration** — PostgreSQL (Bun ORM), MongoDB, Redis
- **Message Brokers** — RabbitMQ, NATS
- **Transport Protocols** — REST (Gorilla Mux), gRPC, WebSockets
- **Common Utilities** — JWT/session management, validation, logging (Zap)

**Repository:** https://github.com/logistics-id/engine

## Core Concepts

### Lifecycle Hooks

Engine manages application lifecycle through three hooks:

1. **`OnStart`** — Initialize dependencies (DB, message brokers, etc.)
2. **`Run`** — Start servers and block until shutdown signal
3. **`OnStop`** — Cleanup resources gracefully

### Signal Handling

Engine automatically handles `SIGINT`/`SIGTERM` for graceful shutdown.

## Basic Application Structure

```go
package main

import (
    "context"
    "os"

    "github.com/joho/godotenv"
    "github.com/logistics-id/engine"
    "github.com/logistics-id/engine/ds/postgres"
    "github.com/logistics-id/engine/broker/rabbitmq"
    "github.com/logistics-id/engine/transport/rest"
)

func init() {
    godotenv.Load()
    engine.Init("service-name", "v1.0.0", false)
}

func main() {
    // OnStart: Initialize dependencies
    engine.OnStart(func(ctx context.Context) error {
        // Connect to PostgreSQL
        pgConfig := postgres.ConfigDefault(os.Getenv("POSTGRES_DATABASE"))
        if err := postgres.NewConnection(pgConfig, engine.Logger); err != nil {
            return err
        }

        // Connect to RabbitMQ
        rmqConfig := rabbitmq.ConfigDefault(engine.Config.Name)
        return rabbitmq.NewConnection(rmqConfig, engine.Logger)
    })

    // OnStop: Cleanup resources
    engine.OnStop(func(ctx context.Context) {
        rabbitmq.CloseConnection()
        postgres.CloseConnection()
    })

    // Run: Start servers
    engine.Run(func(ctx context.Context) {
        // Start REST server
        restServer := rest.NewServer(&rest.Config{
            Server:    os.Getenv("REST_SERVER"),
            IsDev:     engine.Config.IsDev,
            JwtSecret: os.Getenv("JWT_SECRET"),
        }, engine.Logger, registerRoutes)
        
        go restServer.Start(ctx)
        defer restServer.Shutdown(ctx)

        <-ctx.Done()
    })
}

func registerRoutes(srv *rest.RestServer) {
    // Register your routes here
}
```

## Database Integration

### PostgreSQL (Bun ORM)

**Package:** `github.com/logistics-id/engine/ds/postgres`

#### Configuration

```go
import "github.com/logistics-id/engine/ds/postgres"

// Environment variables:
// POSTGRES_SERVER=localhost:5432
// POSTGRES_AUTH_USERNAME=postgres
// POSTGRES_AUTH_PASSWORD=secret

config := postgres.ConfigDefault("mydb")

// Or manual config:
config := &postgres.Config{
    Server:   "localhost:5432",
    Username: "postgres",
    Password: "secret",
    Database: "mydb",
}

// Or DSN:
config := &postgres.Config{
    Datasource: "postgres://user:pass@localhost:5432/mydb?sslmode=disable",
}
```

#### Singleton Pattern (Recommended)

```go
// Initialize once in OnStart
engine.OnStart(func(ctx context.Context) error {
    config := postgres.ConfigDefault(os.Getenv("POSTGRES_DATABASE"))
    return postgres.NewConnection(config, engine.Logger)
})

// Cleanup in OnStop
engine.OnStop(func(ctx context.Context) {
    postgres.CloseConnection()
})

// Access anywhere in your application
db := postgres.GetDB()
```

#### Base Repository Pattern

```go
import (
    "github.com/logistics-id/engine/ds/postgres"
    "github.com/logistics-id/engine/common"
)

type User struct {
    ID        int64  `bun:"id,pk,autoincrement"`
    Email     string `bun:"email"`
    Name      string `bun:"name"`
    IsDeleted bool   `bun:"is_deleted,default:false"`
}

// Create repository
type UserRepository struct {
    *postgres.BaseRepository[User]
}

func NewUserRepository(db *bun.DB) *UserRepository {
    return &UserRepository{
        BaseRepository: postgres.NewBaseRepository[User](
            db,
            "users",                           // table name
            []string{"users.name", "users.email"}, // searchable fields
            []string{},                        // default relations
            true,                              // enable soft delete
        ),
    }
}

// Override WithContext for method chaining
func (r *UserRepository) WithContext(ctx context.Context) *UserRepository {
    return &UserRepository{
        BaseRepository: r.BaseRepository.WithCtx(ctx),
    }
}

// Add custom methods
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
    return r.WithContext(ctx).FindOne(func(q *bun.SelectQuery) *bun.SelectQuery {
        return q.Where("email = ?", email)
    })
}
```

#### Repository Methods

```go
repo := NewUserRepository(postgres.GetDB())

// Insert
user := &User{Email: "john@example.com", Name: "John"}
err := repo.WithContext(ctx).Insert(user)

// Find by ID
user, err := repo.WithContext(ctx).FindByID(1)

// Update
user.Name = "Jane"
err := repo.WithContext(ctx).Update(user, "name")

// Soft delete
err := repo.WithContext(ctx).SoftDelete(1)

// Find all with pagination
opts := &common.QueryOption{
    Page:   1,
    Limit:  10,
    Search: "john",
    Orders: []string{"-created_at"},
}
users, total, err := repo.WithContext(ctx).FindAll(opts, nil)

// Custom query
users, total, err := repo.WithContext(ctx).FindAll(opts, func(q *bun.SelectQuery) *bun.SelectQuery {
    return q.Where("age > ?", 18)
})
```

#### Transactions

```go
// Simple transaction (single repository)
err := repo.RunInTxWithRepo(ctx, func(txRepo *UserRepository) error {
    if err := txRepo.Insert(&user1); err != nil {
        return err
    }
    if err := txRepo.Insert(&user2); err != nil {
        return err
    }
    return nil // Auto-commit on success
})

// Complex transaction (multiple repositories)
err := userRepo.RunInTx(ctx, func(ctx context.Context, tx bun.Tx) error {
    userTxRepo := userRepo.WithTx(ctx, tx)
    orderTxRepo := orderRepo.WithTx(ctx, tx)

    if err := userTxRepo.Insert(&user); err != nil {
        return err
    }
    if err := orderTxRepo.Insert(&order); err != nil {
        return err
    }
    return nil
})
```

### MongoDB

**Package:** `github.com/logistics-id/engine/ds/mongo`

```go
import "github.com/logistics-id/engine/ds/mongo"

// Initialize
engine.OnStart(func(ctx context.Context) error {
    config := mongo.ConfigDefault(os.Getenv("MONGODB_DATABASE"))
    return mongo.NewConnection(config, engine.Logger)
})

engine.OnStop(func(ctx context.Context) {
    mongo.CloseConnection()
})

// Access
db := mongo.GetDB()
collection := mongo.GetCollection("users")
```

### Redis

**Package:** `github.com/logistics-id/engine/ds/redis`

```go
import "github.com/logistics-id/engine/ds/redis"

// Initialize
engine.OnStart(func(ctx context.Context) error {
    config := redis.ConfigDefault()
    return redis.NewConnection(config, engine.Logger)
})

engine.OnStop(func(ctx context.Context) {
    redis.CloseConnection()
})

// Access
client := redis.GetClient()
```

## Message Brokers

### RabbitMQ

**Package:** `github.com/logistics-id/engine/broker/rabbitmq`

#### Configuration

```go
import "github.com/logistics-id/engine/broker/rabbitmq"

// Environment variables:
// RABBIT_SERVER=localhost:5672
// RABBIT_AUTH_USERNAME=guest
// RABBIT_AUTH_PASSWORD=guest

config := rabbitmq.ConfigDefault("myservice") // prefix for topics

// Initialize
engine.OnStart(func(ctx context.Context) error {
    return rabbitmq.NewConnection(config, engine.Logger)
})

engine.OnStop(func(ctx context.Context) {
    rabbitmq.CloseConnection()
})
```

#### Publishing Messages

```go
type OrderCreated struct {
    ID     string  `json:"id"`
    Amount float64 `json:"amount"`
}

// Publish to "myservice.orders.created"
err := rabbitmq.Publish(ctx, "orders.created", OrderCreated{
    ID:     "123",
    Amount: 50.0,
})
```

#### Subscribing to Messages

```go
type OrderCreated struct {
    ID     string  `json:"id"`
    Amount float64 `json:"amount"`
}

// Handler function
func handleOrderCreated(payload OrderCreated, d amqp.Delivery) error {
    fmt.Printf("Received order: %s amount: %f\n", payload.ID, payload.Amount)
    return nil // Success - message will be ACK'd
}

// Register subscription (queue: "myservice.orders.created")
err := rabbitmq.Subscribe("orders.created", handleOrderCreated)
```

#### Context Propagation

RabbitMQ automatically propagates `X-Request-ID` header:

```go
// Publisher side
ctx := context.WithValue(ctx, common.ContextRequestIDKey, "req-123")
rabbitmq.Publish(ctx, "orders.created", data)

// Subscriber side
func handleOrderCreated(payload OrderCreated, d amqp.Delivery) error {
    requestID := d.Headers["X-Request-ID"].(string)
    // Use requestID for logging/tracing
    return nil
}
```

## Transport Protocols

### REST (Gorilla Mux)

**Package:** `github.com/logistics-id/engine/transport/rest`

#### Server Setup

```go
import "github.com/logistics-id/engine/transport/rest"

engine.Run(func(ctx context.Context) {
    server := rest.NewServer(&rest.Config{
        Server:    ":8080",
        IsDev:     engine.Config.IsDev,
        JwtSecret: os.Getenv("JWT_SECRET"),
    }, engine.Logger, registerRoutes)

    go server.Start(ctx)
    defer server.Shutdown(ctx)

    <-ctx.Done()
})

func registerRoutes(srv *rest.RestServer) {
    srv.GET("/users/{id}", GetUserHandler, nil)
    srv.POST("/users", CreateUserHandler, nil)
    srv.PUT("/users/{id}", UpdateUserHandler, srv.WithAuth(true))
    srv.DELETE("/users/{id}", DeleteUserHandler, srv.WithAuth(true, "admin"))
}
```

#### Handler Function

```go
func GetUserHandler(ctx *rest.Context) error {
    id := ctx.Param("id")
    
    user, err := userRepo.WithContext(ctx.Request.Context()).FindByID(id)
    if err != nil {
        return ctx.Respond(nil, err)
    }
    
    return ctx.JSON(200, user)
}
```

#### Request Binding & Validation

```go
import "github.com/logistics-id/engine/validate"

type CreateUserRequest struct {
    Name  string `json:"name" valid:"required|alpha_space"`
    Email string `json:"email" valid:"required|email"`
    Role  string `json:"role" valid:"required|in:admin,user"`
}

func (r *CreateUserRequest) Messages() map[string]string {
    return map[string]string{
        "required": "The %s field is mandatory",
        "email":    "Invalid email format",
    }
}

func CreateUserHandler(ctx *rest.Context) error {
    var req CreateUserRequest
    
    // Bind decodes JSON, binds params, validates
    if err := ctx.Bind(&req); err != nil {
        return ctx.Respond(nil, err)
    }
    
    // Create user...
    return ctx.JSON(201, user)
}
```

#### Query Options (Pagination)

```go
import "github.com/logistics-id/engine/common"

type ListUserRequest struct {
    common.QueryOption
}

func ListUsersHandler(ctx *rest.Context) error {
    var req ListUserRequest
    
    // Auto-binds page, limit, search, order_by from query params
    if err := ctx.Bind(&req); err != nil {
        return ctx.Respond(nil, err)
    }
    
    users, total, err := userRepo.WithContext(ctx.Request.Context()).FindAll(&req.QueryOption, nil)
    if err != nil {
        return ctx.Respond(nil, err)
    }
    
    return ctx.Respond(map[string]any{
        "items": users,
        "total": total,
    }, nil)
}
```

#### Middleware

```go
// Authentication
srv.GET("/profile", ProfileHandler, srv.WithAuth(true))

// Role-based authorization
srv.GET("/admin", AdminHandler, srv.WithAuth(true, "admin"))

// Permission-based authorization
srv.POST("/documents", CreateDocHandler, srv.Restricted("document:create"))
```

### gRPC

**Package:** `github.com/logistics-id/engine/transport/grpc`

```go
import (
    "github.com/logistics-id/engine/transport/grpc"
    pb "github.com/your/repo/proto"
)

engine.Run(func(ctx context.Context) {
    server := grpc.NewServer(&grpc.Config{
        ServiceName:       "user-service",
        Address:           ":9090",
        AdvertisedAddress: "10.0.0.5:9090",
        Namespace:         "microservices",
        TTL:               10 * time.Second,
    }, engine.Logger, nil, func(s *google_grpc.Server) {
        pb.RegisterUserServiceServer(s, &MyUserService{})
    })

    server.Start(ctx)
})
```

## Common Utilities

### JWT & Session Management

**Package:** `github.com/logistics-id/engine/common`

#### Session Claims

```go
import "github.com/logistics-id/engine/common"

type SessionClaims struct {
    UserID      string   `json:"user_id"`
    Username    string   `json:"username"`
    Permissions []string `json:"permission"`
}

// Encode token
claims := &common.SessionClaims{
    UserID:   "123",
    Username: "john",
}
tokens, err := common.TokenEncode(claims)
// Returns: { AccessToken, RefreshToken }

// Decode token
claims, err := common.TokenDecode(tokenStr)

// Get session from context (set by middleware)
claims, err := common.GetSession(ctx)
if err == nil {
    fmt.Println(claims.UserID)
}
```

#### Random Code Generation

```go
// Generate 6-digit numeric code
code := common.RandomCode(6, common.RandomCodeNumeric) // "123456"

// Generate 12-char alphanumeric with separators
code := common.RandomCode(12, common.RandomCodeAlphaNumeric, "-", 4)
// Output: "ABCD-1234-EFGH"
```

### Validation

**Package:** `github.com/logistics-id/engine/validate`

#### Struct Validation

```go
import "github.com/logistics-id/engine/validate"

type CreateUserRequest struct {
    Name  string `valid:"required|alpha_space"`
    Email string `valid:"required|email"`
    Age   int    `valid:"required|min:18|max:100"`
}

func (r *CreateUserRequest) Messages() map[string]string {
    return map[string]string{
        "required": "The %s field is required",
        "email":    "Invalid email format",
        "min":      "Must be at least %s",
    }
}

// Validate
req := &CreateUserRequest{Name: "John", Email: "invalid", Age: 15}
resp := validate.Struct(req)
if resp != nil {
    // resp.Errors contains validation errors
    fmt.Println(resp.Errors)
}
```

#### Available Validators

| Validator | Description | Example |
|---|---|---|
| `required` | Field must not be empty | `valid:"required"` |
| `email` | Valid email format | `valid:"email"` |
| `alpha` | Alphabetic characters only | `valid:"alpha"` |
| `alpha_space` | Alphabetic + spaces | `valid:"alpha_space"` |
| `numeric` | Numeric characters only | `valid:"numeric"` |
| `min:n` | Minimum value/length | `valid:"min:18"` |
| `max:n` | Maximum value/length | `valid:"max:100"` |
| `in:a,b,c` | Value must be in list | `valid:"in:admin,user"` |
| `url` | Valid URL format | `valid:"url"` |
| `uuid` | Valid UUID format | `valid:"uuid"` |

#### Assertions

```go
import "github.com/logistics-id/engine/validate"

// Assert conditions
validate.Assert(user != nil, "User not found")
validate.Assert(user.Age >= 18, "User must be 18 or older")

// Assert with custom error
validate.AssertWithError(balance >= amount, errors.New("insufficient balance"))
```

### Logging

**Package:** `github.com/logistics-id/engine/log`

Engine uses Zap for structured logging. Access via `engine.Logger`.

```go
import "go.uber.org/zap"

// Info
engine.Logger.Info("User created", zap.String("user_id", "123"))

// Error
engine.Logger.Error("Failed to create user", zap.Error(err))

// With context (includes request ID)
requestID := common.GetContextRequestID(ctx)
engine.Logger.Info("Processing request",
    zap.String("request_id", requestID),
    zap.String("user_id", "123"),
)
```

## Configuration Patterns

### Environment Variables

```bash
# .env file
SERVICE_NAME=user-service
SERVICE_VERSION=v1.0.0

# PostgreSQL
POSTGRES_SERVER=localhost:5432
POSTGRES_AUTH_USERNAME=postgres
POSTGRES_AUTH_PASSWORD=secret
POSTGRES_DATABASE=users_db

# RabbitMQ
RABBIT_SERVER=localhost:5672
RABBIT_AUTH_USERNAME=guest
RABBIT_AUTH_PASSWORD=guest

# Redis
REDIS_SERVER=localhost:6379
REDIS_AUTH_PASSWORD=

# REST
REST_SERVER=:8080
JWT_SECRET=your-secret-key

# gRPC
GRPC_SERVER=:9090
```

### Loading Configuration

```go
import "github.com/joho/godotenv"

func init() {
    godotenv.Load()
    engine.Init(
        os.Getenv("SERVICE_NAME"),
        os.Getenv("SERVICE_VERSION"),
        os.Getenv("ENV") == "development",
    )
}
```

## Best Practices

### 1. Use Singleton Pattern for Connections

```go
// ✅ Correct - Initialize once, access anywhere
engine.OnStart(func(ctx context.Context) error {
    return postgres.NewConnection(config, engine.Logger)
})

db := postgres.GetDB() // Access anywhere

// ❌ Wrong - Creating new connections everywhere
client, _ := postgres.NewClient(config, logger)
```

### 2. Always Use Context

```go
// ✅ Correct
repo.WithContext(ctx).FindByID(1)

// ❌ Wrong
repo.FindByID(1) // No context
```

### 3. Graceful Shutdown

```go
// ✅ Correct - Cleanup in OnStop
engine.OnStop(func(ctx context.Context) {
    rabbitmq.CloseConnection()
    postgres.CloseConnection()
})

// ❌ Wrong - No cleanup
```

### 4. Use BaseRepository Pattern

```go
// ✅ Correct - Extend BaseRepository
type UserRepository struct {
    *postgres.BaseRepository[User]
}

// ❌ Wrong - Reimplementing CRUD
type UserRepository struct {
    db *bun.DB
}
func (r *UserRepository) FindByID(id int64) (*User, error) {
    // Manual implementation...
}
```

### 5. Validate Input

```go
// ✅ Correct - Validate with struct tags
type CreateUserRequest struct {
    Email string `json:"email" valid:"required|email"`
}

if err := ctx.Bind(&req); err != nil {
    return ctx.Respond(nil, err)
}

// ❌ Wrong - Manual validation
if req.Email == "" {
    return errors.New("email required")
}
```

### 6. Use Transactions for Multiple Operations

```go
// ✅ Correct
err := repo.RunInTx(ctx, func(ctx context.Context, tx bun.Tx) error {
    // Multiple operations...
    return nil
})

// ❌ Wrong - No transaction
repo.Insert(&user)
repo.Insert(&profile) // If this fails, user is already inserted
```

### 7. Propagate Request ID

```go
// ✅ Correct - Request ID flows through context
requestID := common.GetContextRequestID(ctx)
engine.Logger.Info("Processing", zap.String("request_id", requestID))

// ❌ Wrong - No tracing
engine.Logger.Info("Processing")
```

## Complete Example

```go
package main

import (
    "context"
    "os"

    "github.com/joho/godotenv"
    "github.com/logistics-id/engine"
    "github.com/logistics-id/engine/common"
    "github.com/logistics-id/engine/ds/postgres"
    "github.com/logistics-id/engine/broker/rabbitmq"
    "github.com/logistics-id/engine/transport/rest"
    "github.com/logistics-id/engine/validate"
    "go.uber.org/zap"
)

// Entity
type User struct {
    ID        int64  `bun:"id,pk,autoincrement"`
    Email     string `bun:"email"`
    Name      string `bun:"name"`
    IsDeleted bool   `bun:"is_deleted,default:false"`
}

// Repository
type UserRepository struct {
    *postgres.BaseRepository[User]
}

func NewUserRepository(db *bun.DB) *UserRepository {
    return &UserRepository{
        BaseRepository: postgres.NewBaseRepository[User](
            db, "users",
            []string{"users.name", "users.email"},
            []string{}, true,
        ),
    }
}

// Request
type CreateUserRequest struct {
    Name  string `json:"name" valid:"required|alpha_space"`
    Email string `json:"email" valid:"required|email"`
}

func (r *CreateUserRequest) Messages() map[string]string {
    return map[string]string{
        "required": "The %s field is required",
        "email":    "Invalid email format",
    }
}

// Handler
func CreateUserHandler(ctx *rest.Context) error {
    var req CreateUserRequest
    if err := ctx.Bind(&req); err != nil {
        return ctx.Respond(nil, err)
    }

    repo := NewUserRepository(postgres.GetDB())
    user := &User{Name: req.Name, Email: req.Email}
    
    if err := repo.WithContext(ctx.Request.Context()).Insert(user); err != nil {
        return ctx.Respond(nil, err)
    }

    // Publish event
    rabbitmq.Publish(ctx.Request.Context(), "users.created", map[string]any{
        "id":    user.ID,
        "email": user.Email,
    })

    return ctx.JSON(201, user)
}

func init() {
    godotenv.Load()
    engine.Init("user-service", "v1.0.0", false)
}

func main() {
    engine.OnStart(func(ctx context.Context) error {
        pgConfig := postgres.ConfigDefault(os.Getenv("POSTGRES_DATABASE"))
        if err := postgres.NewConnection(pgConfig, engine.Logger); err != nil {
            return err
        }

        rmqConfig := rabbitmq.ConfigDefault(engine.Config.Name)
        return rabbitmq.NewConnection(rmqConfig, engine.Logger)
    })

    engine.OnStop(func(ctx context.Context) {
        rabbitmq.CloseConnection()
        postgres.CloseConnection()
    })

    engine.Run(func(ctx context.Context) {
        server := rest.NewServer(&rest.Config{
            Server:    os.Getenv("REST_SERVER"),
            IsDev:     engine.Config.IsDev,
            JwtSecret: os.Getenv("JWT_SECRET"),
        }, engine.Logger, func(srv *rest.RestServer) {
            srv.POST("/users", CreateUserHandler, nil)
        })

        go server.Start(ctx)
        defer server.Shutdown(ctx)

        <-ctx.Done()
    })
}
```

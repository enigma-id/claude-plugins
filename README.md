# EVN ID — Claude Code Skills

Skill marketplace for the EVN engineering team. Extends Claude Code with specialized capabilities for database design, Go backend development, engine framework usage, React frontend, ClickUp management, Kubernetes operations, and statusline configuration.

## Install

```bash
# Add marketplace from GitHub
claude plugin marketplace add https://github.com/enigma-id/claude-plugins

# Install EVN skills (includes all 7 skills)
claude plugin install skills@evn.co.id
```

**Setup statusline (one-time):**
```bash
# Configure EVN statusline with ClickUp task tracking
/evn-statusline
```

**Local development:**
```bash
# Add local marketplace
claude plugin marketplace add /Users/alifamri/Works/Enigma/claude-plugins

# Install from local
claude plugin install skills@evn.co.id
```

## Skills

All skills are available under the `skills` plugin:

| Skill | Command | Description | Key Features |
|---|---|---|---|
| `evn-database` | `/evn-database` | PostgreSQL schema design standards | Table naming, soft delete, migrations, indexing |
| `evn-golang` | `/evn-golang` | Go backend clean architecture | Scaffold tools, project structure, REST/gRPC handlers, event-driven |
| `evn-engine` | `/evn-engine` | Engine framework (`logistics-id/engine`) | Lifecycle, database, RabbitMQ, REST/gRPC transport |
| `evn-react` | `/evn-react` | React/TypeScript frontend standards | Component patterns, state management, hooks, forms |
| `evn-clickup` | `/evn-clickup` | ClickUp workspace operations | Task management, documents, team collaboration |
| `evn-kubernetes` | `/evn-kubernetes` | K8s cluster operations | Namespace inventory, deployments, debugging |
| `evn-statusline` | `/evn-statusline` | Statusline configuration | ClickUp task tracking, git status, project context |

## Scaffold Tools (evn-golang)

Generate production-ready Go code:

```bash
SCRIPTS=~/Works/Enigma/claude-plugins/skills/evn-golang/scripts

# Initialize project
$SCRIPTS/scaffold-init.sh github.com/enigma-id/svc-myapi

# Generate from SQL
echo "CREATE TABLE warehouses (...)" | $SCRIPTS/scaffold-entity.sh --from-stdin

# Generate layers
$SCRIPTS/scaffold-usecase.sh Warehouse
$SCRIPTS/scaffold-factory.sh Warehouse
$SCRIPTS/scaffold-handler.sh Warehouse

# gRPC (after writing .proto)
$SCRIPTS/scaffold-grpc.sh Order

# Events
$SCRIPTS/scaffold-publisher.sh Order
$SCRIPTS/scaffold-subscriber.sh order Order
```

**9 Scaffold Scripts:**
- `scaffold-init.sh` — Project skeleton
- `scaffold-entity.sh` — Entity from SQL DDL
- `scaffold-repo.sh` — Repository (auto-chained)
- `scaffold-usecase.sh` — Business logic layer
- `scaffold-factory.sh` — Dependency injection
- `scaffold-handler.sh` — REST handlers + requests
- `scaffold-grpc.sh` — gRPC handler + proto boilerplate
- `scaffold-publisher.sh` — Event publisher
- `scaffold-subscriber.sh` — Event subscriber

## Architecture

### Go Backend (evn-golang + evn-engine)

**Clean Architecture Layers:**
```
Handler → Usecase → Repository → Database
```

**Project Structure:**
```
svc-warehouse/
├── main.go                    # Engine lifecycle
├── entity/                    # Separate module
│   ├── go.mod
│   └── warehouse.go
├── src/
│   ├── handler/
│   │   ├── rest/warehouse/    # REST handlers
│   │   └── grpc/warehouse.go  # gRPC handlers
│   ├── usecase/
│   │   ├── warehouse.go       # Business logic
│   │   └── factory.go         # DI container
│   ├── repository/
│   │   └── warehouse.go       # Data access
│   ├── event/
│   │   ├── publisher/         # Emit events
│   │   └── subscriber/        # Consume events
│   ├── handler.go             # Route registration
│   ├── subscriber.go          # Event registration
│   └── permission.go          # Permission sync
└── proto/                     # gRPC definitions
    ├── go.mod
    ├── warehouse.proto
    ├── constant.go
    └── converter.go
```

**Key Patterns:**
- Entity singularization (warehouses → Warehouse)
- Two naming domains: ENTITY_NAME (data) vs MODULE_NAME (business)
- Automatic validation via `ctx.Bind()` → `validate.Request` interface
- Event-driven with RabbitMQ publishers/subscribers
- gRPC with proto converters

## Development

### Creating a New Skill

Add `SKILL.md` with YAML frontmatter inside `skills/`:

```yaml
---
name: my-skill
description: One-line description of when to use this skill
triggers:
  - keyword1
  - keyword2
---
```

### Validation

```bash
claude plugin validate ./
```

### Local Testing

```bash
# Update marketplace
claude plugin marketplace update evn.co.id

# Reinstall plugin
claude plugin install skills@evn.co.id --force

# Reload plugins in active session
/reload-plugins
```

## Workspace Context

**ClickUp:**
- Workspace: `90181213274`
- Space: Software Development `90184517334`

**Kubernetes:**
- Context: `kubernetes-admin@kubernetes`
- API: `https://10.0.11.11:6443`
- Namespaces: envio, onward, sukabread, tokocare, wordpress, playground, dev-warehouse
---
name: evn-database
description: PostgreSQL database schema design, naming conventions, and migration patterns for EVN backend services
triggers:
  - database
  - schema
  - migration
  - postgres
  - postgresql
  - table
  - column
  - index
  - foreign key
---

# EVN Database Standards

PostgreSQL database schema design standards, naming conventions, and migration patterns for EVN backend services.

## Core Principles

1. **Consistency First** — All tables follow identical naming and structure patterns
2. **Migration-Driven** — Schema changes only through versioned migrations (bun migrate)
3. **Soft Delete by Default** — Preserve data integrity with `is_deleted` flag
4. **Audit Trail** — Every table tracks creation and modification timestamps
5. **Explicit Relationships** — Foreign keys with clear naming and proper indexing

## Naming Conventions

### Tables

- **snake_case** — All lowercase with underscores
- **Plural nouns** — `users`, `orders`, `order_items`
- **No prefixes** — Avoid `tbl_`, `tb_`, or similar prefixes

```sql
-- ✅ Correct
CREATE TABLE users (...);
CREATE TABLE order_items (...);
CREATE TABLE product_categories (...);

-- ❌ Wrong
CREATE TABLE User (...);
CREATE TABLE tbl_orders (...);
CREATE TABLE OrderItem (...);
```

### Columns

- **snake_case** — All lowercase with underscores
- **Descriptive names** — Clear, unambiguous purpose
- **No abbreviations** — `description` not `desc`, `quantity` not `qty`

```sql
-- ✅ Correct
user_id BIGINT
created_at TIMESTAMPTZ
is_deleted BOOLEAN
full_name VARCHAR(255)

-- ❌ Wrong
userId BIGINT
createdAt TIMESTAMP
deleted BOOLEAN
fname VARCHAR(255)
```

### Primary Keys

- **Always `id`** — Single column named `id`
- **BIGSERIAL or UUID** — Choose based on use case (see below)
- **Never composite** — Use surrogate keys, not natural keys

#### BIGSERIAL vs UUID

| Aspect | BIGSERIAL | UUID |
|---|---|---|
| **Use when** | Single database, sequential IDs acceptable | Distributed systems, need globally unique IDs |
| **Performance** | Faster inserts, smaller indexes | Slower inserts, larger indexes |
| **Predictability** | Sequential, predictable | Random, unpredictable |
| **Size** | 8 bytes | 16 bytes |
| **Example** | Internal tables, logs, audit trails | Public-facing entities, distributed services |

**BIGSERIAL (recommended for most tables):**
```sql
-- ✅ Correct — BIGSERIAL for internal tables
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);
```

**UUID (use for distributed systems or public IDs):**
```sql
-- ✅ Correct — UUID for distributed/public entities
CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Note: Requires pgcrypto extension
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

**Wrong patterns:**
```sql
-- ❌ Wrong — wrong column name
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    ...
);

-- ❌ Wrong — composite primary key
CREATE TABLE order_items (
    order_id BIGINT,
    product_id BIGINT,
    PRIMARY KEY (order_id, product_id)
);

-- ❌ Wrong — mixing UUID and BIGSERIAL inconsistently
CREATE TABLE orders (
    id UUID PRIMARY KEY,  -- UUID here
    user_id BIGINT,       -- But BIGINT foreign key
    ...
);
```

**Rule of thumb:** Use BIGSERIAL by default. Use UUID only when:
- Building distributed systems with multiple databases
- Need to generate IDs client-side before insert
- Public-facing IDs that shouldn't be sequential
- Merging data from multiple sources

### Foreign Keys

- **Pattern:** `{referenced_table_singular}_id`
- **Always indexed** — Foreign keys must have indexes
- **Explicit constraints** — Named with pattern `fk_{table}_{column}`

```sql
-- ✅ Correct
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    warehouse_id BIGINT,
    CONSTRAINT fk_orders_user_id FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_orders_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_warehouse_id ON orders(warehouse_id);

-- ❌ Wrong
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    userId BIGINT,  -- Wrong naming
    warehouse BIGINT,  -- Missing _id suffix
    FOREIGN KEY (userId) REFERENCES users(id)  -- Unnamed constraint, no index
);
```

### Indexes

- **Pattern:** `idx_{table}_{column(s)}`
- **Unique indexes:** `uniq_{table}_{column(s)}`
- **Composite indexes:** `idx_{table}_{col1}_{col2}`

```sql
-- ✅ Correct
CREATE INDEX idx_users_email ON users(email);
CREATE UNIQUE INDEX uniq_users_email ON users(email);
CREATE INDEX idx_orders_user_id_created_at ON orders(user_id, created_at);

-- ❌ Wrong
CREATE INDEX users_email_idx ON users(email);
CREATE INDEX idx_email ON users(email);  -- Missing table name
```

## Standard Table Structure

Every table must include these standard columns:

```sql
CREATE TABLE {table_name} (
    -- Primary Key (always first)
    id BIGSERIAL PRIMARY KEY,

    -- Business columns
    -- ...

    -- Audit timestamps (always present)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Soft delete flag (always present)
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Trigger for auto-updating updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_{table_name}_updated_at
    BEFORE UPDATE ON {table_name}
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### Optional Audit Columns

For tables requiring user tracking, add these optional columns:

```sql
CREATE TABLE {table_name} (
    id BIGSERIAL PRIMARY KEY,
    
    -- Business columns
    -- ...
    
    -- Standard audit columns (always present)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Optional user tracking (add when needed)
    created_by BIGINT,
    updated_by BIGINT,
    deleted_by BIGINT,
    
    CONSTRAINT fk_{table_name}_created_by FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT fk_{table_name}_updated_by FOREIGN KEY (updated_by) REFERENCES users(id),
    CONSTRAINT fk_{table_name}_deleted_by FOREIGN KEY (deleted_by) REFERENCES users(id)
);

CREATE INDEX idx_{table_name}_created_by ON {table_name}(created_by);
CREATE INDEX idx_{table_name}_updated_by ON {table_name}(updated_by);
```

**When to add user tracking:**
- Critical business records (orders, invoices, contracts)
- Compliance requirements (audit trails, regulatory)
- Multi-user systems where accountability matters
- NOT needed for: logs, sessions, cache tables, internal system tables

### Optional Multi-Tenancy Column

For multi-tenant systems, add `tenant_id`:

```sql
CREATE TABLE {table_name} (
    id BIGSERIAL PRIMARY KEY,
    
    -- Multi-tenancy (add only if needed)
    tenant_id BIGINT NOT NULL,
    
    -- Business columns
    -- ...
    
    -- Standard audit columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    
    CONSTRAINT fk_{table_name}_tenant_id FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);

-- Composite index for tenant queries
CREATE INDEX idx_{table_name}_tenant_id_created_at ON {table_name}(tenant_id, created_at);

-- Unique constraints must include tenant_id
CREATE UNIQUE INDEX uniq_{table_name}_email_tenant ON {table_name}(email, tenant_id) 
    WHERE is_deleted = FALSE;
```

**Multi-tenancy is NOT standard** — only add when:
- Building SaaS products with multiple customers
- Each tenant's data must be isolated
- Queries always filter by tenant_id

For single-tenant systems, omit `tenant_id` entirely.

### Standard Columns Explained

| Column | Type | Constraint | Purpose |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Unique identifier |
| `created_at` | TIMESTAMPTZ | NOT NULL DEFAULT NOW() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL DEFAULT NOW() | Last modification timestamp |
| `is_deleted` | BOOLEAN | NOT NULL DEFAULT FALSE | Soft delete flag |

### Date Field Naming Standards

For business-specific date fields, use descriptive names with `_at` or `_date` suffix:

**Use `_at` for timestamps (date + time):**
```sql
-- ✅ Correct
published_at TIMESTAMPTZ
scheduled_at TIMESTAMPTZ
completed_at TIMESTAMPTZ
approved_at TIMESTAMPTZ
cancelled_at TIMESTAMPTZ
delivered_at TIMESTAMPTZ
expired_at TIMESTAMPTZ

-- ❌ Wrong
publish_date TIMESTAMPTZ      -- Use published_at
schedule_time TIMESTAMPTZ     -- Use scheduled_at
completion_date TIMESTAMPTZ   -- Use completed_at
```

**Use `_date` for date-only fields (no time component):**
```sql
-- ✅ Correct
birth_date DATE
start_date DATE
end_date DATE
due_date DATE
expiry_date DATE

-- ❌ Wrong
birth_day DATE        -- Use birth_date
start DATE            -- Use start_date
due DATE              -- Use due_date
```

**Common date field patterns:**

| Field Name | Type | Use Case |
|---|---|---|
| `published_at` | TIMESTAMPTZ | When content was published |
| `scheduled_at` | TIMESTAMPTZ | When event is scheduled |
| `completed_at` | TIMESTAMPTZ | When task/order was completed |
| `approved_at` | TIMESTAMPTZ | When approval was granted |
| `cancelled_at` | TIMESTAMPTZ | When cancellation occurred |
| `delivered_at` | TIMESTAMPTZ | When delivery happened |
| `expired_at` | TIMESTAMPTZ | When expiration occurred |
| `verified_at` | TIMESTAMPTZ | When verification happened |
| `start_date` | DATE | Start date (no time) |
| `end_date` | DATE | End date (no time) |
| `due_date` | DATE | Due date (no time) |
| `birth_date` | DATE | Birth date |

**Example table with date fields:**
```sql
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    
    -- Business dates
    ordered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    
    -- Date-only fields
    expected_delivery_date DATE,
    
    -- Standard audit columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);
```

## Data Types

### Strings

```sql
-- Short strings (names, codes, emails)
VARCHAR(255)

-- Long text (descriptions, notes, content)
TEXT

-- Fixed-length codes (country codes, status codes)
CHAR(2)  -- Only when length is truly fixed
```

### Numbers

```sql
-- Primary keys, foreign keys
BIGINT, BIGSERIAL

-- Counters, quantities (non-negative)
INTEGER

-- Money, prices (use NUMERIC for precision)
NUMERIC(15, 2)  -- 15 total digits, 2 decimal places

-- Percentages, rates
NUMERIC(5, 2)  -- e.g., 100.00
```

### Dates & Times

```sql
-- Always use TIMESTAMPTZ (timezone-aware)
TIMESTAMPTZ

-- Date only (no time component)
DATE

-- Time only (rare, avoid if possible)
TIME
```

### Booleans

```sql
-- Flags, status indicators
BOOLEAN NOT NULL DEFAULT FALSE

-- Naming: is_{condition}, has_{feature}, can_{action}
is_active BOOLEAN NOT NULL DEFAULT TRUE
has_verified_email BOOLEAN NOT NULL DEFAULT FALSE
can_login BOOLEAN NOT NULL DEFAULT TRUE
```

### JSON

```sql
-- Structured data, flexible schemas
JSONB  -- Always use JSONB, not JSON (better performance)

-- Example: metadata, settings, configurations
metadata JSONB
settings JSONB DEFAULT '{}'::JSONB
```

## Soft Delete Pattern

All tables use soft delete via `is_deleted` flag. Never hard delete records.

```sql
-- Soft delete implementation
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Index for filtering active records
CREATE INDEX idx_users_is_deleted ON users(is_deleted) WHERE is_deleted = FALSE;

-- Unique constraint that ignores deleted records
CREATE UNIQUE INDEX uniq_users_email_active ON users(email) WHERE is_deleted = FALSE;
```

### Querying with Soft Delete

```sql
-- Active records only (default behavior)
SELECT * FROM users WHERE is_deleted = FALSE;

-- Include deleted records (admin/audit views)
SELECT * FROM users;

-- Soft delete operation
UPDATE users SET is_deleted = TRUE, updated_at = NOW() WHERE id = 123;

-- Restore deleted record
UPDATE users SET is_deleted = FALSE, updated_at = NOW() WHERE id = 123;
```

## Relationships

### One-to-Many

```sql
-- Parent table
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Child table
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    total_amount NUMERIC(15, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    
    CONSTRAINT fk_orders_user_id FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
```

### Many-to-Many

Use junction tables with composite naming: `{table1}_{table2}`

```sql
-- Junction table
CREATE TABLE user_roles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    
    CONSTRAINT fk_user_roles_user_id FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_user_roles_role_id FOREIGN KEY (role_id) REFERENCES roles(id),
    CONSTRAINT uniq_user_roles_user_role UNIQUE (user_id, role_id)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
```

## Migrations (Bun Migrate)

All schema changes must go through versioned migrations.

### Migration File Naming

```
migrations/
├── 20260525120000_create_users_table.up.sql
├── 20260525120000_create_users_table.down.sql
├── 20260525130000_add_users_phone_column.up.sql
├── 20260525130000_add_users_phone_column.down.sql
```

**Pattern:** `{timestamp}_{description}.{up|down}.sql`

### Creating Migrations

```bash
# Generate migration files
bun migrate create create_users_table

# Apply migrations
bun migrate up

# Rollback last migration
bun migrate down

# Check migration status
bun migrate status
```

### Migration Best Practices

1. **Atomic Changes** — One logical change per migration
2. **Reversible** — Always write both `.up.sql` and `.down.sql`
3. **Idempotent** — Safe to run multiple times
4. **Test Rollback** — Verify `.down.sql` works before merging

### Example Migration

**20260525120000_create_users_table.up.sql:**
```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX uniq_users_email_active ON users(email) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_is_deleted ON users(is_deleted) WHERE is_deleted = FALSE;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

**20260525120000_create_users_table.down.sql:**
```sql
DROP TRIGGER IF EXISTS trigger_users_updated_at ON users;
DROP INDEX IF EXISTS idx_users_is_deleted;
DROP INDEX IF EXISTS uniq_users_email_active;
DROP TABLE IF EXISTS users;
```

## Indexing Strategy

### When to Add Indexes

1. **Foreign keys** — Always indexed
2. **Unique constraints** — Automatically indexed
3. **Frequent WHERE clauses** — Columns used in filters
4. **JOIN conditions** — Both sides of the join
5. **ORDER BY columns** — Sorting columns
6. **Soft delete flag** — Partial index on `is_deleted = FALSE`

### Index Types

```sql
-- B-tree (default, most common)
CREATE INDEX idx_users_email ON users(email);

-- Partial index (filtered)
CREATE INDEX idx_users_active ON users(email) WHERE is_deleted = FALSE;

-- Composite index (order matters!)
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);

-- GIN index (for JSONB, arrays, full-text search)
CREATE INDEX idx_products_metadata ON products USING GIN (metadata);

-- Unique index
CREATE UNIQUE INDEX uniq_users_email ON users(email);
```

### Index Naming

| Type | Pattern | Example |
|---|---|---|
| Regular | `idx_{table}_{column(s)}` | `idx_users_email` |
| Unique | `uniq_{table}_{column(s)}` | `uniq_users_email` |
| Composite | `idx_{table}_{col1}_{col2}` | `idx_orders_user_created` |
| Partial | `idx_{table}_{column}_{condition}` | `idx_users_email_active` |

## Common Patterns

### Enum-like Values

Use `VARCHAR` with `CHECK` constraint instead of PostgreSQL ENUMs (more flexible for migrations).

```sql
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    
    CONSTRAINT chk_orders_status CHECK (status IN ('pending', 'processing', 'completed', 'cancelled'))
);

CREATE INDEX idx_orders_status ON orders(status);
```

### Versioning/History Tables

For audit trails, create shadow tables with `_history` suffix.

```sql
CREATE TABLE users_history (
    history_id BIGSERIAL PRIMARY KEY,
    id BIGINT NOT NULL,
    email VARCHAR(255),
    full_name VARCHAR(255),
    operation VARCHAR(10) NOT NULL,  -- INSERT, UPDATE, DELETE
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by BIGINT
);

CREATE INDEX idx_users_history_id ON users_history(id);
CREATE INDEX idx_users_history_changed_at ON users_history(changed_at);
```

### Metadata/Settings Columns

Use JSONB for flexible, schema-less data.

```sql
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Index for JSONB queries
CREATE INDEX idx_products_metadata ON products USING GIN (metadata);

-- Query JSONB
SELECT * FROM products WHERE metadata->>'category' = 'electronics';
SELECT * FROM products WHERE metadata @> '{"featured": true}';
```

### Full-Text Search

For text search functionality, use `tsvector` columns with GIN indexes.

```sql
CREATE TABLE articles (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    search_vector tsvector,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- GIN index for full-text search
CREATE INDEX idx_articles_search_vector ON articles USING GIN (search_vector);

-- Trigger to auto-update search_vector
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.content, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_articles_search_vector
    BEFORE INSERT OR UPDATE ON articles
    FOR EACH ROW
    EXECUTE FUNCTION update_search_vector();

-- Search query
SELECT * FROM articles 
WHERE search_vector @@ to_tsquery('english', 'postgresql & database')
ORDER BY ts_rank(search_vector, to_tsquery('english', 'postgresql & database')) DESC;
```

**When to use full-text search:**
- Article/blog content search
- Product descriptions search
- Document search
- Any text-heavy content requiring keyword search

**Alternative:** For simple LIKE queries, stick with regular VARCHAR/TEXT columns with indexes.

## Schema Documentation

Every migration should include comments for complex logic.

```sql
-- Add comments to tables
COMMENT ON TABLE users IS 'System users with authentication credentials';

-- Add comments to columns
COMMENT ON COLUMN users.password_hash IS 'Bcrypt hashed password (cost factor 12)';
COMMENT ON COLUMN users.is_deleted IS 'Soft delete flag - TRUE means record is deleted';

-- Add comments to constraints
COMMENT ON CONSTRAINT fk_orders_user_id ON orders IS 'Links order to the user who created it';
```

## Performance Considerations

1. **Avoid SELECT *** — Specify columns explicitly
2. **Use LIMIT** — Paginate large result sets
3. **Index foreign keys** — Always
4. **Analyze queries** — Use `EXPLAIN ANALYZE`
5. **Vacuum regularly** — Especially after bulk deletes/updates
6. **Connection pooling** — Configure in application (handled by engine/ds/postgres)

## Security

1. **No sensitive data in plain text** — Hash passwords, encrypt PII
2. **Parameterized queries** — Prevent SQL injection (handled by Bun ORM)
3. **Least privilege** — Application user should not have DDL permissions
4. **Row-level security** — Use PostgreSQL RLS for multi-tenant systems

## Checklist for New Tables

- [ ] Table name is plural, snake_case
- [ ] Primary key is `id BIGSERIAL PRIMARY KEY`
- [ ] Includes `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- [ ] Includes `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- [ ] Includes `is_deleted BOOLEAN NOT NULL DEFAULT FALSE`
- [ ] Has `updated_at` trigger
- [ ] Foreign keys are named `{table}_id` and indexed
- [ ] Foreign key constraints are named `fk_{table}_{column}`
- [ ] Indexes are named `idx_{table}_{column(s)}`
- [ ] Unique constraints are named `uniq_{table}_{column(s)}`
- [ ] Soft delete partial index exists: `WHERE is_deleted = FALSE`
- [ ] Migration has both `.up.sql` and `.down.sql`
- [ ] Migration is tested (up and down)

## Example: Complete Table Definition

```sql
-- Migration: 20260525120000_create_products_table.up.sql

CREATE TABLE products (
    -- Primary key
    id BIGSERIAL PRIMARY KEY,
    
    -- Business columns
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(100) NOT NULL,
    price NUMERIC(15, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    category_id BIGINT NOT NULL,
    metadata JSONB DEFAULT '{}'::JSONB,
    
    -- Audit columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Constraints
    CONSTRAINT fk_products_category_id FOREIGN KEY (category_id) REFERENCES categories(id),
    CONSTRAINT chk_products_price CHECK (price >= 0),
    CONSTRAINT chk_products_stock CHECK (stock_quantity >= 0)
);

-- Indexes
CREATE UNIQUE INDEX uniq_products_sku_active ON products(sku) WHERE is_deleted = FALSE;
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_is_deleted ON products(is_deleted) WHERE is_deleted = FALSE;
CREATE INDEX idx_products_metadata ON products USING GIN (metadata);

-- Trigger for updated_at
CREATE TRIGGER trigger_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE products IS 'Product catalog with inventory tracking';
COMMENT ON COLUMN products.sku IS 'Stock Keeping Unit - unique product identifier';
COMMENT ON COLUMN products.metadata IS 'Flexible JSONB field for product attributes (color, size, etc)';
```

**Rollback migration: 20260525120000_create_products_table.down.sql:**
```sql
DROP TRIGGER IF EXISTS trigger_products_updated_at ON products;
DROP INDEX IF EXISTS idx_products_metadata;
DROP INDEX IF EXISTS idx_products_is_deleted;
DROP INDEX IF EXISTS idx_products_category_id;
DROP INDEX IF EXISTS uniq_products_sku_active;
DROP TABLE IF EXISTS products;
```

package repository

import (
	"context"

	"{{SERVICE_MODULE}}/entity"

	"github.com/logistics-id/engine/common"
	"github.com/logistics-id/engine/ds/postgres"
)

// {{ENTITY_NAME}}Repository handles data access for {{ENTITY_NAME}}.
type {{ENTITY_NAME}}Repository struct {
	*postgres.BaseRepository[entity.{{ENTITY_NAME}}]
}

// New{{ENTITY_NAME}}Repository creates a new {{ENTITY_NAME}}Repository.
// Takes NO parameters — uses postgres.GetDB() internally.
func New{{ENTITY_NAME}}Repository() *{{ENTITY_NAME}}Repository {
	base := postgres.NewBaseRepository[entity.{{ENTITY_NAME}}](
		postgres.GetDB(),
		"{{TABLE_NAME}}",  // tableName
		[]string{"name"},    // searchFields — fields searched by keyword
		nil,                 // preloadRelations — e.g. []string{"Region"}
		true,                // useSoftDelete
	)
	return &{{ENTITY_NAME}}Repository{BaseRepository: base}
}

// WithContext propagates context and returns a new repository instance.
func (r *{{ENTITY_NAME}}Repository) WithContext(ctx context.Context) common.BaseRepositoryInterface[entity.{{ENTITY_NAME}}] {
	return &{{ENTITY_NAME}}Repository{
		BaseRepository: r.BaseRepository.WithContext(ctx).(*postgres.BaseRepository[entity.{{ENTITY_NAME}}]),
	}
}

// =============================================================================
// Add custom repository methods below:
//
// Example — raw aggregate query:
// func (r *{{ENTITY_NAME}}Repository) GetSummary(tenantID string) (*entity.{{ENTITY_NAME}}Summary, error) {
//     query := `SELECT COUNT(*) as total FROM {{TABLE_NAME}} WHERE is_deleted = false`
//     result := new(entity.{{ENTITY_NAME}}Summary)
//     err := r.DB.NewRaw(query).Scan(r.Context, result)
//     return result, err
// }
//
// =============================================================================

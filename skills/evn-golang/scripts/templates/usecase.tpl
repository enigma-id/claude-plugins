package usecase

import (
	"context"

	"{{SERVICE_MODULE}}/entity"
	"{{SERVICE_MODULE}}/src/repository"

	"github.com/logistics-id/engine/common"
	"github.com/uptrace/bun"
)

// {{MODULE_NAME}}Usecase handles business logic for {{MODULE_NAME}}.
type {{MODULE_NAME}}Usecase struct {
	repo *repository.{{MODULE_NAME}}Repository // unexported — only usecase can access
	ctx  context.Context
}

// {{MODULE_NAME}}QueryOptions embeds common.QueryOption and adds module-specific filters.
type {{MODULE_NAME}}QueryOptions struct {
	common.QueryOption
	Status string `query:"status"` // e.g. "active", "inactive"
}

// BuildOption implements common.QueryOption.
func (o *{{MODULE_NAME}}QueryOptions) BuildOption() *common.QueryOption {
	return &o.QueryOption
}

// Get returns a paginated list of {{MODULE_NAME}}.
func (u *{{MODULE_NAME}}Usecase) Get(req *{{MODULE_NAME}}QueryOptions) ([]*entity.{{MODULE_NAME}}, int64, error) {
	return u.repo.FindAll(req.BuildOption(), func(q *bun.SelectQuery) *bun.SelectQuery {
		if req.OrderBy == "" {
			req.OrderBy = "-created_at"
		}
		// Add filters here:
		// if req.Status != "" {
		//     q = q.Where("is_active = ?", req.Status == "active")
		// }
		return q
	})
}

// FindByID returns a single {{MODULE_NAME}} by ID.
func (u *{{MODULE_NAME}}Usecase) FindByID(id string) (*entity.{{MODULE_NAME}}, error) {
	return u.repo.FindByID(id)
}

// Create inserts a new {{MODULE_NAME}} record.
func (u *{{MODULE_NAME}}Usecase) Create(req *entity.{{MODULE_NAME}}) error {
	return u.repo.Insert(req)
}

// Update modifies an existing {{MODULE_NAME}} record.
// Pass field names as variadic args to limit updated columns.
func (u *{{MODULE_NAME}}Usecase) Update(req *entity.{{MODULE_NAME}}, fields ...string) error {
	return u.repo.Update(req, fields...)
}

// Delete performs a soft delete on a {{MODULE_NAME}} record.
func (u *{{MODULE_NAME}}Usecase) Delete(id string) error {
	return u.repo.SoftDelete(id)
}

// WithContext propagates context and returns a new usecase instance.
func (u *{{MODULE_NAME}}Usecase) WithContext(ctx context.Context) *{{MODULE_NAME}}Usecase {
	return &{{MODULE_NAME}}Usecase{
		repo: u.repo.WithContext(ctx).(*repository.{{MODULE_NAME}}Repository),
		ctx:  ctx,
	}
}

// New{{MODULE_NAME}}Usecase creates a new {{MODULE_NAME}}Usecase.
func New{{MODULE_NAME}}Usecase() *{{MODULE_NAME}}Usecase {
	return &{{MODULE_NAME}}Usecase{
		repo: repository.New{{MODULE_NAME}}Repository(),
	}
}

// =============================================================================
// Add business logic methods below:
//
// Example — transaction for atomic update:
// func (u *{{MODULE_NAME}}Usecase) Transfer(fromID, toID string, qty float64) error {
//     tx, err := u.repo.DB.BeginTx(u.ctx, nil)
//     if err != nil { return err }
//     defer tx.Rollback()
//     // ... transfer logic
//     return tx.Commit()
// }
//
// =============================================================================

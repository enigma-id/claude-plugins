package {{MODULE_LOWER}}

import (
	"context"
	"time"

	"{{SERVICE_MODULE}}/entity"
	"{{SERVICE_MODULE}}/src/usecase"

	"github.com/logistics-id/engine/common"
	"github.com/logistics-id/engine/transport/rest"
	"github.com/logistics-id/engine/validate"
)

// createRequest — POST /{{MODULE_PLURAL}}
type createRequest struct {
	Name string `json:"name" valid:"required"`
	// Add more fields here, e.g.:
	// Code    string  `json:"code" valid:"required"`
	// Amount  float64 `json:"amount" valid:"required,gt:0"`

	ctx     context.Context
	uc      *usecase.Factory
	Session *common.SessionClaims // use common.GetContextSession(ctx) — check factory for SessionClaims vs WarehouseSessionClaims
}

func (r *createRequest) Validate() *validate.Response {
	v := validate.NewResponse()

	// ============================================================
	// Add field validations here:
	// Relational validation example:
	// if r.VendorID != "" {
	//     vendor, err := r.uc.Vendor.FindByID(r.VendorID)
	//     if err != nil { v.SetError("vendor_id.invalid", "vendor not found") }
	//     r.vendor = vendor
	// }
	// ============================================================

	return v
}

// Messages returns custom validation error messages.
// Override default validation messages by returning a map of "field.rule" → "custom message".
// Example: return map[string]string{"name.required": "Name is mandatory"}
func (r *createRequest) Messages() map[string]string {
	return map[string]string{}
}

// toEntity builds the entity from the validated request.
func (r *createRequest) toEntity() *entity.{{MODULE_NAME}} {
	return &entity.{{MODULE_NAME}}{
		Name:      r.Name,
		IsActive:  true,
		CreatedAt: time.Now(),
		// Add more fields here
	}
}

// execute inserts the entity via usecase.
func (r *createRequest) execute() (*rest.ResponseBody, error) {
	mx := r.toEntity()
	if err := r.uc.{{MODULE_NAME}}.Create(mx); err != nil {
		return nil, err
	}
	return rest.NewResponseBody(mx), nil
}

// with injects context and factory into the request.
func (r *createRequest) with(ctx context.Context, uc *usecase.Factory) *createRequest {
	r.uc = uc.WithContext(ctx)
	r.ctx = ctx
	// Use GetContextSession or GetContextSessionGeneric depending on your session type
	// r.Session = common.GetContextSession(ctx)
	return r
}

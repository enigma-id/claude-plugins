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

// updateRequest — PUT /{{MODULE_PLURAL}}/{id}
type updateRequest struct {
	ID   string `json:"id" param:"id" valid:"required|uuid"`
	Name string `json:"name"`
	// Add more fields here, e.g.:
	// Amount float64 `json:"amount" valid:"gt:0"`

	ctx      context.Context
	uc       *usecase.Factory
	session  *common.SessionClaims
	existing *entity.{{MODULE_NAME}} // fetched during Validate
}

func (r *updateRequest) Validate() *validate.Response {
	v := validate.NewResponse()

	// Fetch existing record via usecase (NOT repo directly)
	var err error
	r.existing, err = r.uc.{{MODULE_NAME}}.FindByID(r.ID)
	if err != nil {
		v.SetError("id.invalid", "data not found.")
	}

	// ============================================================
	// Add field validations here:
	// Example:
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
func (r *updateRequest) Messages() map[string]string {
	return map[string]string{}
}

// apply updates the existing entity with request fields.
// Only non-zero/non-empty fields are applied (field-level diff).
func (r *updateRequest) apply(e *entity.{{MODULE_NAME}}) {
	if r.Name != "" {
		e.Name = r.Name
	}
	// Add more fields here:
	// if r.Amount > 0 { e.Amount = r.Amount }
	e.UpdatedAt = time.Now()
}

// execute saves the updated entity via usecase.
func (r *updateRequest) execute() (*rest.ResponseBody, error) {
	r.apply(r.existing)

	fields := []string{"name", "updated_at"}
	// Add more fields here: append to fields slice
	// if r.Amount > 0 { fields = append(fields, "amount") }

	if err := r.uc.{{MODULE_NAME}}.Update(r.existing, fields...); err != nil {
		return nil, err
	}
	return rest.NewResponseBody(r.existing), nil
}

// with injects context and factory into the request.
func (r *updateRequest) with(ctx context.Context, uc *usecase.Factory) *updateRequest {
	r.uc = uc.WithContext(ctx)
	r.ctx = ctx
	// r.session = common.GetContextSession(ctx)
	return r
}

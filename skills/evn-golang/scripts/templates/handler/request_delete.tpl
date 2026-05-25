package {{MODULE_LOWER}}

import (
	"context"

	"{{SERVICE_MODULE}}/entity"
	"{{SERVICE_MODULE}}/src/usecase"

	"github.com/logistics-id/engine/transport/rest"
	"github.com/logistics-id/engine/validate"
)

// deleteRequest — DELETE /{{MODULE_PLURAL}}/{id}
type deleteRequest struct {
	ID string `json:"id" param:"id" valid:"required|uuid"`

	ctx      context.Context
	uc       *usecase.Factory
	existing *entity.{{MODULE_NAME}}
}

func (r *deleteRequest) Validate() *validate.Response {
	v := validate.NewResponse()

	// Fetch existing record via usecase (NOT repo directly)
	var err error
	r.existing, err = r.uc.{{MODULE_NAME}}.FindByID(r.ID)
	if err != nil {
		v.SetError("id.invalid", "data not found.")
	}

	return v
}

func (r *deleteRequest) Messages() map[string]string {
	return map[string]string{}
}

// execute performs a soft delete via usecase.
func (r *deleteRequest) execute() (*rest.ResponseBody, error) {
	if err := r.uc.{{MODULE_NAME}}.Delete(r.ID); err != nil {
		return nil, err
	}
	return &rest.ResponseBody{
		Message: "{{MODULE_NAME}} deleted successfully",
	}, nil
}

// with injects context and factory into the request.
func (r *deleteRequest) with(ctx context.Context, uc *usecase.Factory) *deleteRequest {
	r.uc = uc.WithContext(ctx)
	r.ctx = ctx
	return r
}

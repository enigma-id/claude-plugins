package {{MODULE_LOWER}}

import (
	"context"

	"{{SERVICE_MODULE}}/src/usecase"

	"github.com/logistics-id/engine/transport/rest"
)

type getRequest struct {
	Download bool `query:"download"` // set to true for Excel export

	usecase.{{MODULE_NAME}}QueryOptions
	uc  *usecase.Factory
	ctx context.Context
}

// get returns a paginated list of {{MODULE_NAME}}.
func (r *getRequest) get() (*rest.ResponseBody, error) {
	// Override limit for export
	if r.Download {
		r.Limit = 100000
		r.Page = 1
	}

	data, total, err := r.uc.{{MODULE_NAME}}.Get(&r.{{MODULE_NAME}}QueryOptions)
	if err != nil {
		return nil, err
	}

	return rest.NewResponseBody(
		data,
		rest.BuildMeta(r.Page, r.Limit, total),
	), nil
}

// detail returns a single {{MODULE_NAME}} by ID.
func (r *getRequest) detail(id string) (*rest.ResponseBody, error) {
	data, err := r.uc.{{MODULE_NAME}}.FindByID(id)
	if err != nil {
		return nil, err
	}
	return rest.NewResponseBody(data), nil
}

// with injects context and factory into the request.
func (r *getRequest) with(ctx context.Context, uc *usecase.Factory) *getRequest {
	r.ctx = ctx
	r.uc = uc.WithContext(ctx)
	return r
}

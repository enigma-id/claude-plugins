package {{MODULE_LOWER}}

import (
	"{{SERVICE_MODULE}}/src/usecase"

	"github.com/logistics-id/engine/transport/rest"
)

type handler struct {
	uc *usecase.Factory
}

// HandlerList — GET /{{MODULE_PLURAL}}
// @Summary Get list of {{MODULE_PLURAL}}
// @Accept json
// @Produce json
// @Param limit query int64 false "limit pagination"
// @Param page query int64 false "pagination"
// @Param search query string false "name"
// @Param order_by query string false "id / -id"
// @Success 200 {object} rest.ResponseBody
// @Failure default {object} rest.HTTPError
// @Router /{{MODULE_PLURAL}} [get]
func (h *handler) get(ctx *rest.Context) (err error) {
	var req getRequest
	var res *rest.ResponseBody

	if err = ctx.Bind(req.with(ctx, h.uc)); err == nil {
		res, err = req.get()
	}

	return ctx.Respond(res, err)
}

// HandlerShow — GET /{{MODULE_PLURAL}}/{id}
// @Summary Get {{MODULE_NAME}} by ID
// @Accept json
// @Produce json
// @Param id path string true "{{MODULE_NAME}} id"
// @Success 200 {object} rest.ResponseBody
// @Failure default {object} rest.HTTPError
// @Router /{{MODULE_PLURAL}}/{id} [get]
func (h *handler) show(ctx *rest.Context) (err error) {
	var req getRequest
	var res *rest.ResponseBody

	if err = ctx.Bind(req.with(ctx, h.uc)); err == nil {
		res, err = req.detail(ctx.Param("id"))
	}

	return ctx.Respond(res, err)
}

// HandlerCreate — POST /{{MODULE_PLURAL}}
// @Summary Create new {{MODULE_NAME}}
// @Accept json
// @Produce json
// @Param body body createRequest true "{{MODULE_NAME}} data"
// @Success 200 {object} rest.ResponseBody
// @Failure default {object} rest.HTTPError
// @Router /{{MODULE_PLURAL}} [post]
func (h *handler) create(ctx *rest.Context) (err error) {
	var req createRequest
	var res *rest.ResponseBody

	if err = ctx.Bind(req.with(ctx, h.uc)); err == nil {
		res, err = req.execute()
	}
	return ctx.Respond(res, err)
}

// HandlerUpdate — PUT /{{MODULE_PLURAL}}/{id}
// @Summary Update {{MODULE_NAME}}
// @Accept json
// @Produce json
// @Param id path string true "{{MODULE_NAME}} id"
// @Param body body updateRequest true "{{MODULE_NAME}} data"
// @Success 200 {object} rest.ResponseBody
// @Failure default {object} rest.HTTPError
// @Router /{{MODULE_PLURAL}}/{id} [put]
func (h *handler) update(ctx *rest.Context) (err error) {
	var req updateRequest
	var res *rest.ResponseBody

	if err = ctx.Bind(req.with(ctx, h.uc)); err == nil {
		res, err = req.execute()
	}
	return ctx.Respond(res, err)
}

// HandlerDelete — DELETE /{{MODULE_PLURAL}}/{id}
// @Summary Delete {{MODULE_NAME}}
// @Accept json
// @Produce json
// @Param id path string true "{{MODULE_NAME}} id"
// @Success 200 {object} rest.ResponseBody
// @Failure default {object} rest.HTTPError
// @Router /{{MODULE_PLURAL}}/{id} [delete]
func (h *handler) delete(ctx *rest.Context) (err error) {
	var req deleteRequest
	var res *rest.ResponseBody

	if err = ctx.Bind(req.with(ctx, h.uc)); err == nil {
		res, err = req.execute()
	}
	return ctx.Respond(res, err)
}

// RegisterHandler registers the REST handlers for the {{MODULE_NAME}} module.
func RegisterHandler(s *rest.RestServer) {
	h := &handler{
		uc: usecase.NewFactory(),
	}

	s.GET("/{{MODULE_PLURAL}}", h.get, s.Restricted())
	s.POST("/{{MODULE_PLURAL}}", h.create, s.Restricted("{{SERVICE_NAME}}.{{MODULE_LOWER}}.manage"))
	s.GET("/{{MODULE_PLURAL}}/{id}", h.show, s.Restricted())
	s.PUT("/{{MODULE_PLURAL}}/{id}", h.update, s.Restricted("{{SERVICE_NAME}}.{{MODULE_LOWER}}.manage"))
	s.DELETE("/{{MODULE_PLURAL}}/{id}", h.delete, s.Restricted("{{SERVICE_NAME}}.{{MODULE_LOWER}}.manage"))
}

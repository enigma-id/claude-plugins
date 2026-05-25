package usecase

import "context"

// Factory holds all usecase instances for the service.
type Factory struct {
	{{MODULE_NAME}} *{{MODULE_NAME}}Usecase
	// Add other usecases here:
	// Item  *ItemUsecase
	// Order *OrderUsecase
}

// NewFactory creates a new Factory with all usecases.
// Takes NO parameters — repositories call postgres.GetDB() internally.
func NewFactory() *Factory {
	return &Factory{
		{{MODULE_NAME}}: New{{MODULE_NAME}}Usecase(),
		// Item:  NewItemUsecase(),
		// Order: NewOrderUsecase(),
	}
}

// WithContext returns a new Factory with context propagated to all usecases.
func (f *Factory) WithContext(ctx context.Context) *Factory {
	return &Factory{
		{{MODULE_NAME}}: f.{{MODULE_NAME}}.WithContext(ctx),
		// Item:  f.Item.WithContext(ctx),
		// Order: f.Order.WithContext(ctx),
	}
}

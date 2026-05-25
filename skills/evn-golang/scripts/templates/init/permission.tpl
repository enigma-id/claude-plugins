package src

import (
	"context"
	"time"

	"github.com/logistics-id/engine"
)

// RegisterPermission registers service permissions into the platform.
// Called via: go src.RegisterPermission(ctx) with a startup delay.
func RegisterPermission(ctx context.Context) {
	// Wait for service to be fully ready before registering
	time.Sleep(10 * time.Second)

	// use logger if needed
	// _ = engine.Logger

	// Register permissions here:
	// Example:
	// permissions := []map[string]string{
	// 	{"code": "{{SERVICE_NAME}}.module.manage", "name": "Manage Module"},
	// 	{"code": "{{SERVICE_NAME}}.module.view", "name": "View Module"},
	// }
	// ... call platform permission API
}

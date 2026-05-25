package src

import (
	// "github.com/logistics-id/engine/broker/rabbitmq"
	// "{{SERVICE_MODULE}}/src/event/subscriber"
)

// RegisterSubscriber registers all RabbitMQ event subscribers.
// MUST be called inside engine.Run(), NOT in init() or top-level main().
func RegisterSubscriber() {
	// Register subscribers here:
	// rabbitmq.Subscribe("entity.action", subscriber.SubscribeEntityAction)
}

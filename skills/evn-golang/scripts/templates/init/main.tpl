package main

import (
	"context"
	"os"

	"github.com/joho/godotenv"
	"github.com/logistics-id/engine"
	"github.com/logistics-id/engine/broker/rabbitmq"
	"github.com/logistics-id/engine/ds/postgres"
	"github.com/logistics-id/engine/ds/redis"
	"github.com/logistics-id/engine/transport/grpc"
	"github.com/logistics-id/engine/transport/rest"

	"{{SERVICE_MODULE}}/src"
)

func init() {
	godotenv.Load()
	engine.Init("{{SERVICE_NAME}}")

	// Register cronjobs (uncomment if needed)
	// src.RegisterCronjob()
}

// @title {{SERVICE_NAME}}
// @description
// @version v1
// @host {URL}/{version}/{{SERVICE_NAME}}
// @BasePath /
func main() {
	engine.OnStart(initiateConnection)

	engine.OnStop(closeConnection)

	engine.Run(func(ctx context.Context) {
		// Register subscribers
		src.RegisterSubscriber()

		// Start REST server
		transportREST := rest.NewServer(&rest.Config{
			Server: os.Getenv("REST_SERVER"),
			IsDev:  engine.Config.IsDev,
		}, engine.Logger, src.RegisterRestRoutes)

		go transportREST.Start(ctx)
		defer transportREST.Shutdown(ctx)

		// Start gRPC server
		transportGRPC := grpc.NewService(&grpc.Config{
			ServiceName:       engine.Config.Name,
			Namespace:         os.Getenv("PLATFORM"),
			Address:           os.Getenv("GRPC_SERVER"),
			AdvertisedAddress: os.Getenv("GRPC_ADDRESS"),
		}, engine.Logger, src.RegisterGrpcRoutes)

		go transportGRPC.Start(ctx)
		defer transportGRPC.Shutdown(ctx)

		// Register permissions after services are up
		go src.RegisterPermission(ctx)

		<-ctx.Done()
	})
}

// initiateConnection is used to initiate any connections needed for the service
// For example, connecting to a database or a message broker
func initiateConnection(ctx context.Context) error {
	// Initialize Redis connection
	if err := redis.NewConnection(redis.ConfigDefault(engine.Config.Name), engine.Logger); err != nil {
		return err
	}

	// Initialize PostgreSQL connection
	if err := postgres.NewConnection(postgres.ConfigDefault(os.Getenv("POSTGRES_DATABASE")), engine.Logger); err != nil {
		return err
	}

	// Initialize RabbitMQ connection
	return rabbitmq.NewConnection(rabbitmq.ConfigDefault(engine.Config.Name), engine.Logger)
}

// closeConnection is used to close the connections to the services
// such as PostgreSQL and RabbitMQ when the service stops.
func closeConnection(ctx context.Context) {
	postgres.CloseConnection()
	rabbitmq.CloseConnection()
}

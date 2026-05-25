package src

import (
	"github.com/logistics-id/engine/transport/rest"
)

// RegisterRestRoutes registers all REST route handlers.
// Called from: rest.NewServer(ctx, engine.Config.Name, src.RegisterRestRoutes)
func RegisterRestRoutes(s *rest.RestServer) {
	// Register module handlers here:
	// deliveryplan.RegisterHandler(s)
}

// RegisterGrpcRoutes registers all gRPC service handlers.
// Called from: grpc.NewService(ctx, engine.Config.Name, src.RegisterGrpcRoutes)
// func RegisterGrpcRoutes(srv *grpc.GrpcServer) {
// 	uc := usecase.NewFactory()
// 	proto.RegisterXxxServiceServer(srv, &xxxHandler{uc: uc})
// }

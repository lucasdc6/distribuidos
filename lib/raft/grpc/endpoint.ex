defmodule Raft.GRPC.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run Raft.GRPC.Server
end

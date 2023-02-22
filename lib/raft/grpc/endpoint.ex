defmodule Raft.GRPC.Endpoint do
  use GRPC.Endpoint

  run Raft.GRPC.Server
end

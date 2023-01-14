defmodule Raft.Server.RequestVoteParams do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :current_term, 1, type: :int64, json_name: "currentTerm"
end

defmodule Raft.Server.RequestVoteReply do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :server_id, 1, type: :int64, json_name: "serverId"
  field :vote, 2, type: :bool
end

defmodule Raft.Server.GRPC.Service do
  @moduledoc false
  use GRPC.Service, name: "Raft.Server.GRPC", protoc_gen_elixir_version: "0.11.0"

  rpc :RequestVote, Raft.Server.RequestVoteParams, Raft.Server.RequestVoteReply
end

defmodule Raft.Server.GRPC.Stub do
  @moduledoc false
  use GRPC.Stub, service: Raft.Server.GRPC.Service
end

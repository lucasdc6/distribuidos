defmodule Raft.Server.RequestVoteParams do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :term, 1, type: :int64
  field :candidate_id, 2, type: :int64, json_name: "candidateId"
  field :last_log_index, 3, type: :int64, json_name: "lastLogIndex"
end

defmodule Raft.Server.RequestVoteReply do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :term, 1, type: :int64
  field :vote_granted, 2, type: :bool, json_name: "voteGranted"
end

defmodule Raft.Server.SetTermParams do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :term, 1, type: :int64
end

defmodule Raft.Server.SetMembershipParams do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :membership_state, 1, type: :string, json_name: "membershipState"
end

defmodule Raft.Server.AppendEntriesParams do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :term, 1, type: :int64
  field :leader_id, 2, type: :int64, json_name: "leaderId"
  field :prev_log_index, 3, type: :int64, json_name: "prevLogIndex"
  field :prev_log_term, 4, type: :int64, json_name: "prevLogTerm"
  field :entries, 5, repeated: true, type: :int64
  field :leader_commit, 6, type: :int64, json_name: "leaderCommit"
end

defmodule Raft.Server.RunCommandParams do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :command, 1, type: :int64
end

defmodule Raft.Server.ResultReply do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :result, 1, type: :bool
end

defmodule Raft.Server.AppendEntriesReply do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :term, 1, type: :int64
  field :success, 2, type: :bool
end

defmodule Raft.Server.GRPC.Service do
  @moduledoc false
  use GRPC.Service, name: "raft.server.GRPC", protoc_gen_elixir_version: "0.11.0"

  rpc :RequestVote, Raft.Server.RequestVoteParams, Raft.Server.RequestVoteReply

  rpc :SetMembership, Raft.Server.SetMembershipParams, Raft.Server.ResultReply

  rpc :SetTerm, Raft.Server.SetTermParams, Raft.Server.ResultReply

  rpc :AppendEntries, Raft.Server.AppendEntriesParams, Raft.Server.AppendEntriesReply

  rpc :RunCommand, Raft.Server.RunCommandParams, Raft.Server.ResultReply
end

defmodule Raft.Server.GRPC.Stub do
  @moduledoc false
  use GRPC.Stub, service: Raft.Server.GRPC.Service
end
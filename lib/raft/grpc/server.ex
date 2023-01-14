defmodule Raft.GRPC.Server do
  use GRPC.Server, service: Raft.Server.GRPC.Service
  require Raft.Server

  def child_spec(arg) do
    IO.inspect(arg)
  end

  @spec request_vote(Raft.Server.RequestVoteParams.t(), GRPC.Server.Stream.t())
        :: Raft.Server.RequestVoteReply.t()
  def request_vote(request, _stream) do
    metadata = Raft.Config.get(Raft.Config, "metadata")
    state = Raft.Config.get(Raft.Config, "state")
    Raft.Server.RequestVoteReply.new(
      server_id: Raft.Server.metadata(metadata, :id),
      vote: state.current_term < request.current_term
    )
  end
end


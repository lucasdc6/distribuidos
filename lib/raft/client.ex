defmodule Raft.Client do
  defp connect() do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    channel
  end

  def vote(current_term) do
    channel = connect()

    request = Raft.Server.RequestVoteParams.new(current_term: current_term)
    {:ok, _reply} = channel |> Raft.Server.GRPC.Stub.request_vote(request)
  end

  def vote() do
    channel = connect()

    request = Raft.Server.RequestVoteParams.new(current_term: 1)
    {:ok, _reply} = channel |> Raft.Server.GRPC.Stub.request_vote(request)
  end
end

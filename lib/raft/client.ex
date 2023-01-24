defmodule Raft.Client do
  @moduledoc """
  Module to communicate with the Raft server
  """
  defp connect() do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    channel
  end

  @spec vote(integer) :: {:ok, any}
  def vote(current_term) do
    channel = connect()

    request = Raft.Server.RequestVoteParams.new(current_term: current_term)
    {:ok, _reply} = channel |> Raft.Server.GRPC.Stub.request_vote(request)
  end

  @spec vote :: {:ok, any}
  def vote() do
    channel = connect()

    request = Raft.Server.RequestVoteParams.new(current_term: 1)
    {:ok, _reply} = channel |> Raft.Server.GRPC.Stub.request_vote(request)
  end

  def append_entries() do
    channel = connect()
    request = Raft.Server.AppendEntriesParams.new(entries: [1,2,3])
    {:ok, _reply} = channel |> Raft.Server.GRPC.Stub.append_entries(request)
  end
end

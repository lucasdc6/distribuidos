defmodule Raft.GRPC.Server do
  use GRPC.Server, service: Raft.Server.GRPC.Service
  require Logger
  require Raft.Server

  @spec connect(String.t(), Integer.t(), Integer.t()) :: %{channel: nil | GRPC.Channel.t(), peer: String.t()}
  @doc """
  Connect to GRPC peer

  ```elixir
  iex> Raft.GRPC.Server.connect("localhost:50051", 5, 5)
  ```
  """
  def connect(peer, retry_time, retry_wait_time) do
    Logger.notice("Connecting to peer #{peer}")
    case GRPC.Stub.connect(peer) do
      {:ok, channel} ->
        Logger.notice("Connected with peer #{peer}")
        %{peer: peer, channel: channel}
      {:error, err} ->
        Logger.error("Failed to connect with the peer time #{retry_time}: #{err}")
        if retry_time > 0 do
          Logger.notice("Wait #{retry_wait_time}s until connection retry")
          Process.sleep(retry_wait_time * 1000)
          connect(peer, retry_time - 1, retry_wait_time * 2)
        end
        %{peer: peer, channel: nil}
    end
  end

  @spec request_vote(Raft.Server.RequestVoteParams.t(), GRPC.Server.Stream.t())
        :: Raft.Server.RequestVoteReply.t()
  def request_vote(request, _stream) do
    metadata = Raft.Config.get("metadata")
    state = Raft.Config.get("state")
    Raft.Server.RequestVoteReply.new(
      candidate_id: Raft.Server.metadata(metadata, :id),
      term: state.current_term,
      vote: state.current_term < request.term
    )
  end

  def set_membership(request, _stream) do
    state = Raft.Config.get("state")
    valid_membership_state = request.membership_state in ["follower", "candidate", "leader", "shutdown"]

    if valid_membership_state do
      Raft.Config.put("state", %Raft.State{current_term: state.current_term, membership_state: String.to_atom(request.membership_state)})
    end

    Raft.Server.ResultReply.new(
      result: valid_membership_state
    )
  end

  def set_term(request, _stream) do
    state = Raft.Config.get("state")
    Raft.Config.put("state", %Raft.State{
      current_term: request.term,
      membership_state: state.membership_state
    })

    Raft.Server.ResultReply.new(
      result: true
    )
  end
end

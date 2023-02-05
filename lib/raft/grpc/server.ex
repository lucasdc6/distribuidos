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

  def send_heartbeat(server_id, state, peer) do
    request = Raft.Server.AppendEntriesParams.new(
      term: state.current_term,
      leader_id: server_id,
      prev_log_index: state.last_index,
      prev_log_term: state.current_term,
      entries: [],
      leader_commit: state.commit_index
    )
    case Raft.Server.GRPC.Stub.append_entries(peer.channel, request) do
      {:ok, %{success: true}} ->
        next_index = Raft.State.update_next_index(
            state.next_index,
            peer.peer,
            0
          )
        Logger.info("Successful heartbeat from #{peer.peer} - #{inspect(next_index)}")

        Raft.Config.put("state", %Raft.State{
          state |
          next_index: next_index
        })

      {:ok, %{success: false, term: reply_term}} ->
        Logger.info("Unsuccessful heartbeat from #{peer.peer}")
        next_index = Enum.find(state.next_index, %{value: 0}, fn elem ->
          elem.server_id == peer.peer
        end)
        Logger.debug("Next index: #{inspect(next_index)}")
        cond do
          reply_term > state.current_term ->
            Logger.info("Newer term discovered: #{reply_term}")
            Raft.Config.put("state", %Raft.State{
              state |
              membership_state: :follower
            })
          next_index.value > 0 ->
            next_index = Raft.State.update_next_index(
              state.next_index,
              peer.peer,
              next_index.value - 1
            )
            Raft.Config.put("state", %Raft.State{
              state |
              next_index: next_index
            })
            Logger.info("Retry heartbeat with next_index = #{next_index.value}")
            send_heartbeat(server_id, state, peer)
          true ->
            Logger.error("Error")
        end
      {_, err} ->
        Logger.error("Error on heartbeat from #{peer.peer}: #{err}")
    end
  end

  ###########
  # Helpers #
  ###########
  defp check_entries(%Raft.State{logs: []}, _) do
    true
  end

  defp check_entries(state, request) do
    Enum.any?(state.logs, &(&1.index == request.prev_log_index and &1.term == request.prev_log_term))
  end

  @spec vote_reply(Raft.Server.RequestVoteParams.t(), Raft.State.t()) :: Raft.Server.RequestVoteReply.t()
  #vote_reply process a request and a state to return a final GRPC reply
  defp vote_reply(request, state) when state.membership_state != :follower and request.term > state.current_term do
    Logger.debug("Lost leadership because received a request_vote with a newer term")

    Raft.State.update(%{
      membership_state: :follower,
      current_term: request.term
    })

    Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: false
    )
  end

  defp vote_reply(_request, state) do
    Raft.Server.RequestVoteReply.new(
      term: state.current_term
    )
  end

  @spec process_vote(Raft.Server.RequestVoteParams.t(), Raft.State.t()) :: Raft.Server.RequestVoteReply.t()
  @doc """
  process_vote
    - In case that the request term is older than the state term, ignore it
    - In case that the request term is newer than the state term, increase the state term
  """
  # request term is older than the state term, ignore it
  def process_vote(request, state) when request.term < state.current_term do
    Logger.debug("Reject vote because it's an older term - request.term(#{request.term}) < state.current_term(#{state.current_term})")
    vote_reply(request, state)
  end

  def process_vote(request, state) when request.term >= state.current_term and
                                         request.term == state.last_vote_term and
                                         state.voted_for != nil and
                                         request.candidate_id == state.voted_for do
    Logger.debug("Duplicate request_vote for same term: #{request.term}")
    reply = vote_reply(request, state)
    Map.put(reply, :vote_granted, true)
  end

  def process_vote(request, state) when request.term >= state.current_term and
                                         request.term == state.last_vote_term and
                                         state.voted_for != nil do
    Logger.debug("Duplicate request_vote for candidate: #{request.candidate_id}")
    vote_reply(request, state)
  end

  def process_vote(request, state) do
    reply = vote_reply(request, state)
    Map.put(reply, :vote_granted, true)
  end

  #######################
  # Standard Procedures #
  #######################
  @spec request_vote(Raft.Server.RequestVoteParams.t(), GRPC.Server.Stream.t())
        :: Raft.Server.RequestVoteReply.t()
  def request_vote(request, _stream) do
    state = Raft.Config.get("state")
    case state.voted_for do
      nil ->  Raft.Config.put("state", %Raft.State{
                state |
                voted_for: request.candidate_id
              })
              Raft.Server.RequestVoteReply.new(
                term: state.current_term,
                vote_granted: state.current_term <= request.term && state.last_index <= request.last_log_index
              )

      _ ->    Raft.Server.RequestVoteReply.new(
                term: state.current_term,
                vote_granted: false
              )
    end
  end

  def append_entries(request, _stream) do
    state = Raft.Config.get("state")
    Logger.debug("Current state: #{inspect(state)}")
    success = check_entries(state, request)
    index = state.last_index + 1
    entries = Enum.map(request.entries, fn entry ->
      %{index: index, term: state.current_term, command: entry}
    end)
    Logger.info("AppendEntries state #{success}")

    Raft.Config.put("state", %Raft.State{
      state |
      logs: state.logs ++ entries,
      voted_for: nil,
      membership_state: keep_or_change(state.membership_state),
      current_term: update_term(state.current_term, request.term)
    })

    Raft.Timer.set(state, :heartbeat_timer_ref)
    updated_state = Raft.Config.get("state")

    Raft.Server.AppendEntriesReply.new(
      term: updated_state.current_term,
      success: success
    )
  end

  defp update_term(current_term, request_term) do
    if request_term > current_term, do: request_term, else: current_term
  end

  defp keep_or_change(membership_state) do
    case membership_state do
      :candidate -> :follower
      _ -> membership_state
    end
  end

  ###########################
  # Non Standard Procedures #
  ###########################
  def run_command(request, _stream) do
    state = Raft.Config.get("state")
    index = state.last_index + 1

    # If command received from client:
    # * append entry to local log
    # * respond after entry applied to state machine - TODO
    if state.membership_state == :leader do
      Raft.Config.put("state", %Raft.State{
        state |
        last_index: index,
        logs: state.logs ++ [%{index: index, term: state.current_term, command: request.command}]
      })
    end

    # Wait until entry is applied
    Raft.Server.ResultReply.new(
      result: state.membership_state == :leader
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
end

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

  ###########
  # Helpers #
  ###########

  defp check_entries(state, request) do
    cond do
      request.prev_log_index == 0 -> true
      true ->
        Enum.any?(
          state.logs,
          &(&1.index == request.prev_log_index and &1.term == request.prev_log_term)
        )
    end
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
                vote_granted: state.current_term <= request.term && state.last_applied <= request.last_log_index
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

    if success do
      old_logs = Enum.filter(state.logs, fn log -> log.index < request.prev_log_index + 1 end)
      new_logs = old_logs ++ request.entries
      Raft.Config.put("state", %Raft.State{
        state |
        logs: old_logs ++ request.entries,
        last_applied: length(new_logs),
        voted_for: nil,
        membership_state: keep_or_change(state.membership_state),
        current_term: update_term(state.current_term, request.term)
      })
    end
    Raft.Server.AppendEntriesReply.new(
      term: state.current_term,
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
    index = state.last_applied + 1

    # If command received from client:
    # * append entry to local log
    # * respond after entry applied to state machine - TODO
    if state.membership_state == :leader do
      Raft.Config.put("state", %Raft.State{
        state |
        last_applied: index,
        logs: state.logs ++ [%{index: index, term: state.current_term, command: inspect(request.command)}]
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

defmodule Raft.Server do
  @moduledoc """
  Raft server
  This module define the entrypoint for all the processes
  """
  import Record
  require Logger

  @type metadata :: record(:metadata, id: integer)
  defrecord :metadata, id: 0

  @spec run(Raft.State) :: {:shutdown}
  @doc """
  Run the main Raft process
  """
  def run(state = %{membership_state: :follower}) do
    timeout = Enum.random(4000..6000)
    Logger.notice("Node in #{state.membership_state} mode")
    Process.sleep(timeout)

    state = Raft.Config.get("state")
    Logger.debug("state: #{inspect(state)}, timeout: #{timeout}")

    run(state)
  end

  def run(state = %{membership_state: :candidate}) do
    Logger.notice("Node in #{state.membership_state} mode")
    metadata = Raft.Config.get("metadata")

    # On conversion to candidate, start election:
    #  * Increment currentTerm
    #  * Vote for self
    #  * Reset election timer - TODO
    #  * Send RequestVote RPCs to all other servers
    state = %Raft.State{
      state |
      current_term: state.current_term + 1,
      votes: state.votes ++ [metadata(metadata, :id)]
    }
    Raft.Config.put("state", state)
    peers = Raft.Config.get("peers")
    votes_needed = ceil(length(peers) / 2 + 1)
    Logger.info("Votes needed for the quorum: #{votes_needed}")
    try do
      for peer <- peers do
        Logger.notice("Request vote to server #{peer.peer}")
        request = Raft.Server.RequestVoteParams.new(
          term: state.current_term,
          last_log_index: state.last_index,
          candidate_id: metadata(metadata, :id)
        )

        case Raft.Server.GRPC.Stub.request_vote(peer.channel, request) do
          {:ok, reply} ->
            Logger.debug("request_vote response: #{inspect(reply)}")
            cond do
              reply.term > state.current_term ->
                Raft.Config.put("state", %Raft.State{
                  membership_state: :follower,
                  current_term: reply.term,
                  votes: []
                })
                throw(%{code: :fallback, term: reply.term})
              reply.vote ->
                new_state = %Raft.State{
                  state |
                  votes: [ peer | state.votes ]
                }
                Raft.Config.put("state", new_state)
                Logger.notice("Vote granted from #{reply.candidate_id}")
                Logger.info("Vote count: #{length(new_state.votes)}")

                if votes_needed <= length(new_state.votes) do
                  Raft.Config.put("state", %Raft.State{
                    membership_state: :leader,
                    current_term: state.current_term,
                    votes: new_state.votes
                  })
                throw(%{code: :elected})
                end
              true ->
                Logger.info("Denied vote")
            end
          {_, err} ->
            Logger.error("Failed in request vote: #{err}")
        end
      end
    catch
      %{code: :fallback, term: term} ->
        Logger.notice("Newer term discovered: #{term}")
      %{code: :elected} ->
        Logger.notice("Election won with term #{state.current_term}")
      _ ->
        Logger.error("Unkwnown error")
    end
    Logger.debug("Refresh state")
    state = Raft.Config.get("state")

    run(state)
  end

  def run(state = %{membership_state: :leader}) do
    timeout = Enum.random(4000..6000)
    Logger.notice("Node in #{state.membership_state} mode")

    peers = Raft.Config.get("peers")
    metadata = Raft.Config.get("metadata")

    Enum.map(peers, fn(peer) ->
      # Upon election: send initial empty AppendEntries RPCs
      # (heartbeat) to each server; repeat during idle periods to
      # prevent election timeouts (§5.2)

      state = Raft.Config.get("state")
      Raft.GRPC.Server.send_heartbeat(metadata(metadata, :id), state, peer)
    end)

    Process.sleep(timeout)

    state = Raft.Config.get("state")
    state.logs
    |> Enum.drop_while(&(&1.index > state.last_index))
    |> Enum.map(fn(log) ->
      Enum.map(peers, fn(peer) ->
        request = Raft.Server.AppendEntriesParams.new(
          term: state.current_term,
          leader_id: metadata(metadata, :id),
          # FIX - change the real log term
          prev_log_term: state.current_term,
          prev_log_index: state.last_index,
          entries: [log.command],
          leader_commit: state.commit_index
        )
        Logger.debug("Sending log entries (#{inspect(log)}) ) to #{peer.peer}")

        case Raft.Server.GRPC.Stub.append_entries(peer.channel, request) do
          {:ok, %{success: true}} ->
            Logger.info("Applied log entries (#{inspect(log)})")

          {:ok, %{success: false, term: term}} ->
            Logger.info("Newer term discovered: #{term}")

          {_, err} ->
            Logger.error("Error applying entry #{log}: #{err}")
        end
      end)
    end)
    Logger.debug("state: #{inspect(state)}")
    #Logger.debug("not applied logs: #{inspect(not_applied_logs)}")

    run(state)
  end

  def run(_) do
    {:shutdown}
  end

  @doc """
  Initialize the server

  Example:

  iex> Raft.Server.init(
    %Raft.State{},
    []
  )

  """
  def init(state, arguments) do
    # initialize metadata
    metadata = metadata(id: :rand.uniform(100000))

    Logger.notice("Starting server with id \##{metadata(metadata, :id)}")

    # Configure Config and GRCP processes
    children = [
      {
        Raft.Config,
        id: Raft.Config
      },
      {
        GRPC.Server.Supervisor,
        endpoint: Raft.GRPC.Endpoint,
        port: arguments[:port] || 50051,
        start_server: true,
      }
    ]

    # Configure supervisor strategy and name
    opts = [strategy: :one_for_one, name: Raft]
    # Start process
    Supervisor.start_link(children, opts)

    peers = arguments
      |> Keyword.get_values(:peer)
      |> Enum.map(fn peer ->
        Raft.GRPC.Server.connect(peer, 5, 5)
      end)

    # Update raft central state
    Raft.Config.put("metadata", metadata)
    Raft.Config.put("state", state)
    Raft.Config.put("peers", peers)

    run(state)
    Logger.notice("Shutting down server with id \##{metadata(metadata, :id)}")
    {:ok}
  end
end

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
    timeout = Enum.random(200..5000)
    Logger.notice("Node in #{state.membership_state} mode")
    state = Raft.Config.get("state")

    if is_nil(state.heartbeat_timer_ref) do
      Logger.info("Started heartbeat timer")
      Raft.Timer.set(state, :heartbeat_timer_ref, timeout)
    end

    Process.sleep(1000)
    Logger.debug("state: #{inspect(state)}, timeout: #{timeout}")

    run(state)
  end

  def run(state = %{membership_state: :candidate}) do
    Logger.notice("Node in #{state.membership_state} mode")
    metadata = Raft.Config.get("metadata")
    Raft.Config.put("state", %Raft.State{
      state |
      current_term: state.current_term + 1,
      votes: [metadata(metadata, :id)],
      voted_for: metadata(metadata, :id)
      })

    timeout = Enum.random(4000..6000)

    if is_nil(state.heartbeat_timer_ref) do
      Logger.info("Started election timer")
      Raft.Timer.set(state, :heartbeat_timer_ref, timeout)
    end

    Process.sleep(timeout)
    # On conversion to candidate, start election:
    #  * Increment currentTerm
    #  * Vote for self
    #  * Reset election timer - TODO
    #  * Send RequestVote RPCs to all other servers
    peers = Raft.Config.get("peers")
    votes_needed = ceil(length(peers) / 2 + 1)
    %{term: last_term} = Raft.State.get_last_log(state)
    Logger.info("Votes needed for the quorum: #{votes_needed}")

    request = Raft.Server.RequestVoteParams.new(
      term: state.current_term,
      last_log_index: state.last_applied,
      last_log_term: last_term,
      candidate_id: metadata(metadata, :id)
    )
    tasks = peers
            |> Enum.map(fn(peer) ->
                 Task.async(fn() -> %{
                   vote: Raft.Server.GRPC.Stub.request_vote(peer.channel, request),
                   peer: peer.peer}
                 end)
               end)

    responses = Task.await_many(tasks)

    try do
      for response <- responses do
        Logger.notice("Request vote to server #{response.peer}")
        state = Raft.Config.get("state")

        case response.vote do
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
              reply.vote_granted ->
                new_state = %Raft.State{
                  state |
                  votes: [response.peer] ++ state.votes
                }
                Raft.Config.put("state", new_state)
                Logger.notice("Vote granted from #{response.peer}")
                Logger.info("Vote count: #{length(new_state.votes)} - #{inspect(new_state.votes)}")

                if votes_needed <= length(new_state.votes) do
                  next_index = Raft.State.initialize_next_index_for_leader(state, peers)

                  Raft.Config.put("state", %Raft.State{
                    state |
                    membership_state: :leader,
                    current_term: state.current_term,
                    votes: new_state.votes,
                    next_index: next_index
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
        Logger.error("Unknown error")
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
    state = Raft.Config.get("state")

    tasks = peers
            |> Enum.map(fn(peer) ->
                Task.async(fn() ->
                  follower_info = Raft.State.get_follower_data(state, peer.peer)
                  logs = Raft.State.get_logs_for_follower(state.logs, follower_info.index)
                  request = map_append_entries_request(state, metadata, logs, follower_info)

                  %{
                    request: request,
                    append_reply: Raft.Server.GRPC.Stub.append_entries(peer.channel, request),
                    peer: peer.peer
                  }
                end)
              end)
    responses = Task.await_many(tasks)

    for response <- responses do
      Logger.notice("request append entries to server #{response.peer} - request: #{inspect(response.request)}")
      state = Raft.Config.get("state")

      case response.append_reply do
        {:ok, %{success: true}} ->
          Logger.info("Successful append entries from #{response.peer}")
          last_log = Raft.State.find_log(state.logs, state.current_term, state.last_applied)
          next_index = Raft.State.update_next_index(state, response.peer, state.last_applied, last_log.term)

          Raft.Config.put("state", %Raft.State{
            state |
            next_index: next_index
          })

        {:ok, %{success: false, term: reply_term}} ->
          Logger.info("Unsuccessful append entries from #{response.peer}")
          follower_info = Raft.State.get_follower_data(state, response.peer)
          cond do
            reply_term > state.current_term ->
              Logger.info("Newer term discovered: #{reply_term}")
              Raft.Config.put("state", %Raft.State{
                state |
                membership_state: :follower
              })
            follower_info.index > 0 ->
              Logger.info("Decrement follower index for next heartbeat")

              decremented_index = follower_info.index - 1
              prev_log = Raft.State.find_log(state.logs, state.current_term, decremented_index)
              next_index = Raft.State.update_next_index(
                state,
                response.peer,
                follower_info.index - 1,
                prev_log.term
              )

              Raft.Config.put("state", %Raft.State{
                state |
                next_index: next_index
              })

            true ->
              Logger.error("Error")
          end

        {_, err} ->
          Logger.error("Error applying entry #{response.request}- peer #{response.peer}: #{err}")
      end
    end

    Process.sleep(timeout)
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
    :timer.start

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

  defp map_append_entries_request(state, metadata, logs, follower_info) do
    Raft.Server.AppendEntriesParams.new(
      term: state.current_term,
      leader_id: metadata(metadata, :id),
      prev_log_index: follower_info.index,
      prev_log_term: follower_info.term,
      entries: logs,
      leader_commit: state.commit_index
    )
  end
end

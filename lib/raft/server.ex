defmodule Raft.Server do
  @moduledoc """
  Raft server
  This module define the entrypoint for all the processes
  """
  import Record
  require Logger

  @type metadata :: record(:metadata, id: integer)
  defrecord :metadata, id: 0, pid: nil

  @spec run(Raft.State) :: {:shutdown}
  @doc """
  Run the main Raft process
  """
  def run(state = %{membership_state: :follower}) do
    timeout = Enum.random(2000..6000)
    Logger.debug("Node in #{state.membership_state} mode")
    Process.sleep(2500)
    state = Raft.Config.get("state")

    if is_nil(state.heartbeat_timer_ref) do
      Logger.debug("Started heartbeat timer")
      Raft.Timer.set(state, :heartbeat_timer_ref, timeout)
    end

    Logger.debug("state: #{inspect(state)}, timeout: #{timeout}")

    receive do
      :heartbeat_timer_reset ->
        Logger.notice("Receive a heartbeat from the leader #{state.leader_id}")
        Raft.Timer.cancel(state, :heartbeat_timer_ref)
        state = Raft.State.update(%{
          heartbeat_timer_ref: nil
        })
        run(state)
      :heartbeat_timer_timeout ->
        Logger.warn("Heartbeat timeout reached, starting election")
        state = Raft.State.update(%{
          membership_state: :candidate,
          heartbeat_timer_ref: nil
        })
        run(state)
    end
  end

  def run(state = %{membership_state: :candidate}) do
    Logger.debug("Node in #{state.membership_state} mode")
    Process.sleep(2500)
    metadata = Raft.Config.get("metadata")
    timeout = Enum.random(2000..6000)

    # On conversion to candidate, start election:
    #  * Reset election timer
    if is_nil(state.election_timer_ref) do
      Logger.info("Started election timer")
      Raft.Timer.set(state, :election_timer_ref, timeout)
    end

    # On conversion to candidate, start election:
    #  * Increment currentTerm
    #  * Vote for self
    Raft.State.update(%{
      current_term: state.current_term + 1,
      votes: [metadata(metadata, :id)],
      voted_for: metadata(metadata, :id)
      })

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

    # On conversion to candidate, start election:
    #  * Send RequestVote RPCs to all other servers
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
        Logger.debug("Request vote to server #{response.peer}")
        state = Raft.Config.get("state")
        votes_denied = 0

        case response.vote do
          {:ok, reply} ->
            Logger.debug("request_vote response: #{inspect(reply)}")
            cond do
              reply.term > state.current_term ->
                Raft.State.update(%{
                  membership_state: :follower,
                  current_term: reply.term,
                  votes: []
                })
                throw(%{code: :fallback, term: reply.term})
              reply.vote_granted ->
                new_state = %{
                  votes: [response.peer] ++ state.votes
                }
                Raft.State.update(new_state)
                Logger.debug("Vote granted from #{response.peer}")
                Logger.info("Vote count: #{length(new_state.votes)} - #{inspect(new_state.votes)}")

                if votes_needed <= length(new_state.votes) do
                  next_index = Raft.State.initialize_next_index_for_leader(state, peers)

                  Raft.State.update(%{
                    membership_state: :leader,
                    current_term: state.current_term,
                    votes: new_state.votes,
                    next_index: next_index
                  })
                end
              true ->
                Logger.info("Denied vote from #{response.peer}")
                votes_denied = votes_denied - 1
                if votes_denied >= votes_needed do
                  throw(%{code: :denied})
                end
            end
          {_, err} ->
            Logger.error("Failed in request vote: #{err}")
        end
      end
    catch
      %{code: :fallback, term: term} ->
        Logger.notice("Newer term discovered: #{term}")
        state = Raft.State.update(%{
          membership_state: :follower,
          votes: []
        })
        Raft.Timer.cancel(state, :election_timer_ref)
        run(state)
      %{code: :elected} ->
        Logger.notice("Election won with term #{state.current_term}")
        state = Raft.State.update(%{
          membership_state: :leader
        })
        Raft.Timer.cancel(state, :election_timer_ref)
        run(state)
      %{code: :denied}
        Logger.info("Election denied")
        state = Raft.State.update(%{
          membership_state: :follower,
          votes: []
        })
        Raft.Timer.cancel(state, :election_timer_ref)
        run(state)
      _ ->
        Logger.error("Unknown error")
    end

    # Refresh state
    state = Raft.Config.get("state")
    if state.membership_state == :leader do
      Logger.notice("Election won with term #{state.current_term}")
      Raft.Timer.cancel(state, :election_timer_ref)
      run(state)
    end

    receive do
      :election_timer_reset ->
        Logger.warn("Fallback")
        state = Raft.State.update(%{
          membership_state: :follower,
          votes: []
        })
        Raft.Timer.cancel(state, :election_timer_ref)
        run(state)
      :election_timer_timeout ->
        Logger.warn("Election timeout reached, restarting election")
        state = Raft.State.update(%{
          membership_state: :candidate,
          votes: []
        })
        run(state)
    end
  end

  def run(state = %{membership_state: :leader}) do
    # timeout = Enum.random(2000..6000)
    Logger.debug("Node in #{state.membership_state} mode")
    Process.sleep(2500)

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
      Logger.debug("request append entries to server #{response.peer} - request: #{inspect(response.request)}")
      state = Raft.Config.get("state")

      case response.append_reply do
        {:ok, %{success: true}} ->
          Logger.notice("Successful append entries from #{response.peer}")
          last_log = Raft.State.find_log(state.logs, state.current_term, state.last_applied)
          next_index = Raft.State.update_next_index(state, response.peer, state.last_applied, last_log.term)

          Raft.State.update(%{
            next_index: next_index
          })

        {:ok, %{success: false, term: reply_term}} ->
          Logger.debug("Unsuccessful append entries from #{response.peer}")
          follower_info = Raft.State.get_follower_data(state, response.peer)
          cond do
            reply_term > state.current_term ->
              Logger.debug("Newer term discovered: #{reply_term}")
              Raft.State.update(%{
                membership_state: :follower
              })
            follower_info.index > 0 ->
              Logger.debug("Decrement follower index for next heartbeat")

              decremented_index = follower_info.index - 1
              prev_log = Raft.State.find_log(state.logs, state.current_term, decremented_index)
              next_index = Raft.State.update_next_index(
                state,
                response.peer,
                follower_info.index - 1,
                prev_log.term
              )

              Raft.State.update(%{
                next_index: next_index
              })

            true ->
              Logger.error("Unknown error")
          end

        {_, err} ->
          Logger.error("Error applying entry #{inspect(response.request)} - peer #{response.peer}: #{inspect(err)}")
      end
    end

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
    metadata = metadata(id: :rand.uniform(100000), pid: self())

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

    Process.sleep(2000)
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

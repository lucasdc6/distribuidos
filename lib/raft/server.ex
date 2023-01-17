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

    run(state.membership_state)
  end

  def run(state = %{membership_state: :candidate}) do
    timeout = Enum.random(4000..6000)
    Logger.notice("Node in #{state.membership_state} mode")
    Process.sleep(timeout)

    state = %Raft.State{state | current_term: state.current_term + 1}
    Raft.Config.put("state", state)

    peers = Raft.Config.get("peers")
    votes_needed = ceil(length(peers) / 2 + 1)
    Logger.info("Votes needed for the quorum: #{votes_needed}")
    try do
      for peer <- peers do
        Logger.notice("Request vote to server #{peer.peer}")
        request = Raft.Server.RequestVoteParams.new(term: state.current_term)

        case Raft.Server.GRPC.Stub.request_vote(peer.channel, request) do
          {:ok, reply} ->
            Logger.debug("request_vote response: #{inspect(reply)}")
            cond do
              reply.term > state.current_term ->
                Raft.Config.put("state", %Raft.State{
                  membership_state: :follower,
                  current_term: reply.term,
                  voted_for: []
                })
                throw(:fallback)
              reply.vote ->
                new_state = %Raft.State{
                  state |
                  voted_for: [ reply.candidate_id | state.voted_for ]
                }
                Raft.Config.put("state", new_state)
                Logger.notice("Vote granted from #{reply.candidate_id}")
                Logger.info("Vote count: #{length(new_state.voted_for)}")

                if votes_needed <= length(new_state.voted_for) do
                  Raft.Config.put("state", %Raft.State{
                    membership_state: :leader,
                    current_term: state.current_term,
                    voted_for: new_state.voted_for
                  })
                  throw(:elected)
                end
              true ->
                Logger.info("Denied vote")
            end
          {_, err} ->
            Logger.error("Failed in request vote: #{err}")
        end
      end
    catch
      :fallback ->
        Logger.notice("Newer term discovered")
      :elected ->
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
    Process.sleep(timeout)

    state = Raft.Config.get("state")
    Logger.debug("state: #{inspect(state)}, timeout: #{timeout}")

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

    run(state.membership_state)
    Logger.notice("Shutting down server with id \##{metadata(metadata, :id)}")
    {:ok}
  end
end

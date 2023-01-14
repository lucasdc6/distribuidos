defmodule Raft.Server do
  @moduledoc """
  Raft server
  This module define the entrypoint for all the processes
  """
  import Record
  require Logger

  @type metadata :: record(:metadata, id: integer)
  defrecord :metadata, id: 0

  @spec run(Raft.State) :: {:candidate} | {:follower} | {:leader} | {:shutdown}
  @doc """
  Run the main Raft process
  """
  def run(membership_state =  :follower) do
    timeout = Enum.random(4500..5500)
    Logger.notice("Node in #{membership_state} mode")
    Process.sleep(timeout)

    state = Raft.Config.get("state")
    Logger.debug("state: #{inspect(state)}, timeout: #{timeout}")
    if state.membership_state == membership_state do
      Raft.Config.put("state", %Raft.State{membership_state: state.membership_state, current_term: state.current_term + 1})
    end

    run(state.membership_state)
  end

  def run(membership_state = :candidate) do
    timeout = Enum.random(4500..5500)
    Logger.notice("Node in #{membership_state} mode")
    Process.sleep(timeout)

    state = Raft.Config.get("state")
    Logger.debug("state: #{inspect(state)}, timeout: #{timeout}")
    if state.membership_state == membership_state do
      Raft.Config.put("state", %Raft.State{membership_state: state.membership_state, current_term: state.current_term + 1})
    end

    run(state.membership_state)
  end

  def run(membership_state = :leader) do
    timeout = Enum.random(4500..5500)
    Logger.notice("Node in #{membership_state} mode")
    Process.sleep(timeout)

    state = Raft.Config.get("state")
    Logger.debug("state: #{inspect(state)}, timeout: #{timeout}")
    if state.membership_state == membership_state do
      Raft.Config.put("state", %Raft.State{membership_state: state.membership_state, current_term: state.current_term + 1})
    end

    run(state.membership_state)
  end

  def run(_) do
    {:shutdown}
  end

  @doc """
  Initialize the server

  """
  def init(state, arguments) do
    # initialize metadata
    metadata = metadata(id: :rand.uniform(100000))
    peers = Keyword.get_values(arguments, :peer)

    Logger.notice("Starting server with id \##{metadata(metadata, :id)}")
    Logger.debug("Peers: #{inspect(peers)}")

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

    # Update raft central state
    Raft.Config.put("metadata", metadata)
    Raft.Config.put("state", state)
    run(state.membership_state)
    Logger.notice("Shutting down server with id \##{metadata(metadata, :id)}")
    {:ok}
  end
end

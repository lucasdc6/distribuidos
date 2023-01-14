defmodule Raft.Server do
  @moduledoc """
  Raft server
  This module define the entrypoint for all the processes
  """
  import Record
  require Logger

  @type metadata :: record(:metadata, id: integer)
  defrecord :metadata, id: 0

  @spec run(Raft.State) :: {:candidate} | {:follower} | {:leader} | {:noop}
  @doc """
  Run the main Raft process
  """
  def run(state = %Raft.State{membership_state: :follower}) do
    Logger.info("Starting #{state.membership_state}")
    Process.sleep(5000)
    run(state)
    {:follower}
  end

  def run(state = %Raft.State{membership_state: :candidate}) do
    Logger.info("Starting #{state.membership_state}")
    Process.sleep(5000)
    run(state)
    {:candidate}
  end

  def run(state = %Raft.State{membership_state: :leader}) do
    Logger.info("Starting #{state.membership_state}")
    Process.sleep(5000)
    run(state)
    {:leader}
  end

  def run(_) do
    {:noop}
  end

  @spec init(Raft.State) :: {:candidate} | {:follower} | {:leader} | {:noop}
  @doc """
  Initialize the server

  """
  def init(state) do
    # initialize metadata
    metadata = metadata(id: :rand.uniform(100000))

    Logger.info("Starting server with id \##{metadata(metadata, :id)}")

    # Configure Config and GRCP processes
    children = [
      {
        Raft.Config,
        id: Raft.Config
      },
      {
        GRPC.Server.Supervisor,
        endpoint: Raft.GRPC.Endpoint,
        port: 50051,
        start_server: true,
      }
    ]

    # Configure supervisor strategy and name
    opts = [strategy: :one_for_one, name: Raft]
    # Start process
    Supervisor.start_link(children, opts)

    # Update raft central state
    Raft.Config.put(Raft.Config, "metadata", metadata)
    Raft.Config.put(Raft.Config, "state", state)
    run(state)
  end
end

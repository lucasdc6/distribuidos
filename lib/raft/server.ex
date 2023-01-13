defmodule Raft.Server do
  import Record
  require Logger

  @type metadata :: record(:metadata, id: integer)
  defrecord :metadata, id: 0

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

  def init(state) do
    metadata = metadata(id: :rand.uniform(100000))
    Logger.info("Starting server with id \##{metadata(metadata, :id)}")
    run(state)
  end
end

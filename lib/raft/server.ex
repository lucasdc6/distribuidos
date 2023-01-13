defmodule Raft.Server do
  import Record

  require Logger
  require Raft.State

  @type metadata :: record(:metadata, id: integer)
  defrecord :metadata, id: 0

  def follower() do
    Logger.info("Starting follower")
    {:follower}
  end

  def candidate() do
    Logger.info("Starting candidate")
    {:candidate}
  end

  def leader() do
    Logger.info("Starting leader")
    {:leader}
  end

  def noop() do
    {:noop}
  end

  def init(state) do
    metadata = metadata(id: :rand.uniform(100000))
    Logger.info("Starting server with id \##{metadata(metadata, :id)}")
    run(state)
  end

  def run(state) do
    case Raft.State.state(state, :membership_state) do
      :follower ->
        follower()
        Process.sleep(5000)
        run(state)
      :candidate -> candidate()
      :leader -> leader()
      _ -> noop()
    end
  end
end

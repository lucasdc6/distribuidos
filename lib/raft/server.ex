defmodule Raft.Server do
  import Record
  require Logger

  defrecord :metadata, id: :nil

  def id(m) do
    metadata(m, :id)
  end

  def follower(metadata) do
    Logger.info("Starting follower with id \##{id(metadata)}")
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

  def fack() do
    {:fack}
  end

  def init(id, state) do
    metadata = metadata(id: id)
    run(state, metadata)
  end

  def run(state, metadata) do
    case Raft.State.membership(state) do
      :follower ->
        follower(metadata)
        run(state, metadata)
      :candidate -> candidate()
      :leader -> leader()
      _ -> fack()
    end
  end
end

defmodule Raft.Timer do
  require Logger
  require Raft.Server

  def send_timeout(server_pid, timer) do
    Logger.debug("SEND :#{timer} to #{inspect(server_pid)} - ref = #{inspect(self())}")
    send(server_pid, timer)
  end

  def set(state, timer = :election_timer_ref, timeout) do
    metadata = Raft.Config.get("metadata")
    server_pid = Raft.Server.metadata(metadata, :pid)

    timer_ref = Map.get(state, timer)

    if timer_ref, do: cancel(state, timer)

    case :timer.apply_after(timeout, Raft.Timer, :send_timeout, [server_pid, :election_timer_timeout]) do
      {:ok, ref} ->
        Raft.State.update(%{
          election_timer_ref: ref
        })
      _ ->
        {:error, "Unknown error"}
    end
  end

  def set(state, timer = :heartbeat_timer_ref, timeout) do
    metadata = Raft.Config.get("metadata")
    server_pid = Raft.Server.metadata(metadata, :pid)

    timer_ref = Map.get(state, timer)

    if timer_ref, do: cancel(state, timer)

    case :timer.apply_after(timeout, Raft.Timer, :send_timeout, [server_pid, :heartbeat_timer_timeout]) do
      {:ok, ref} ->
        Raft.State.update(%{
          heartbeat_timer_ref: ref
        })
      _ ->
        {:error, "Unknown error"}
    end
  end

  def cancel(state, timer = :election_timer_ref) do
    timer_ref = Map.get(state, timer)
    if timer_ref do
      case :timer.cancel(timer_ref) do
        {:ok, _} ->
          Logger.debug("Cancel timer")
        {:error, err} ->
          Logger.error("Error canceling the timer: #{err}")
      end
    end
    Raft.State.update(%{
      election_timer_ref: nil
    })
  end

  def cancel(_state, timer = :heartbeat_timer_ref) do
    state = Raft.Config.get("state")
    timer_ref = Map.get(state, timer)
    if timer_ref do
      case :timer.cancel(timer_ref) do
        {:ok, _} ->
          Logger.debug("Cancel timer")
        {:error, err} ->
          Logger.error("Error canceling the timer: #{err}")
      end
    end
    Raft.State.update(%{
      heartbeat_timer_ref: nil
    })
  end
end

defmodule Raft.Timer do
  require Logger
  require Raft.Server

  def set(state, timer = :election_timer_ref, timeout) do
    metadata = Raft.Config.get("metadata")
    server_pid = Raft.Server.metadata(metadata, :pid)

    timer_ref = Map.get(state, timer)

    if timer_ref, do: cancel(state, timer)

    case :timer.apply_after(timeout, Kernel, :send, [server_pid, :election_timer_timeout]) do
      {:ok, ref} ->
        {:ok, ref}
      _ ->
        {:error, "Unknown error"}
    end
  end

  def set(state, timer = :heartbeat_timer_ref, timeout) do
    metadata = Raft.Config.get("metadata")
    server_pid = Raft.Server.metadata(metadata, :pid)

    timer_ref = Map.get(state, timer)

    if timer_ref, do: cancel(state, timer)

    case :timer.apply_after(timeout, Kernel, :send, [server_pid, :heartbeat_timer_timeout]) do
      {:ok, ref} ->
        {:ok, ref}
      _ ->
        {:error, "Unknown error"}
    end
  end

  def cancel(state, timer) do
    timer_ref = Map.get(state, timer)
    if timer_ref do
      case :timer.cancel(timer_ref) do
        {:ok, _} ->
          Logger.debug("Cancel timer")
        {:error, err} ->
          Logger.error("Error canceling the timer: #{err}")
      end
    end
  end
end

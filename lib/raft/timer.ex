defmodule Raft.Timer do
  require Logger

  @spec start(Raft.State, atom(), Integer.t()) :: {:ok, :timer.tref()} | {:error, String.t()}
  def start(state, timer, timeout \\ 5000) do
    case :timer.apply_after(timeout, Raft.Config, :put, ["state", %Raft.State{state | membership_state: :candidate}]) do
      {:ok, ref} ->
        Raft.Config.put("state", Map.put(state, timer, ref))
        {:ok, ref}
      _ ->
        {:error, "Unknown error"}
    end
  end

  @spec cancel(Raft.State, atom()) :: {:error, any} | {:ok, :cancel}
  def cancel(state, timer) do
    Logger.info("Cancel timer")
    timer_ref = Map.get(state, timer)
    case :timer.cancel(timer_ref) do
      {:ok, _} ->
        Raft.Config.put("state", Map.put(state, timer, nil))
      {:error, err} ->
        Logger.error("Error canceling the timer: #{err}")
    end
  end

  @spec restart(Raft.State, atom(), Integer.t()) :: {:ok, :timer.tref()} | {:error, String.t()}
  def restart(state, timer, timeout \\ 5000) do
    cancel(state, timer)
    start(state, timer, timeout)
  end

end

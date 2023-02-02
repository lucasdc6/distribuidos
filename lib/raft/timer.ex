defmodule Raft.Timer do
  require Logger

  def timeout(overwrite) do
    state = Raft.Config.get("state")

    Raft.Config.put("state", Map.merge(state, overwrite))
  end

  def set(state, timer, timeout \\ 5000) do
    timer_ref = Map.get(state, timer)
    overwrite = Map.put(%{membership_state: :candidate}, timer, nil)

    if timer_ref, do: cancel(state, timer)

    case :timer.apply_after(timeout, Raft.Config, :timeout, [overwrite]) do
      {:ok, ref} ->
        Raft.Config.put("state", Map.put(state, timer, ref))
        {:ok, ref}
      _ ->
        {:error, "Unknown error"}
    end
  end

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
end

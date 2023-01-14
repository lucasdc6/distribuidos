defmodule Raft.Config do
  @moduledoc """
  Centralized state for a raft server
  """
  use Agent
  require Logger

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  @doc """
  Initialize the config agent.
  """
  def start_link(_opts) do
    Logger.info("Starting #{__MODULE__} agent")
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec get(any) :: any
  @doc """
  Gets a value from the Config by `key`.
  """
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @spec put(any, any) :: :ok
  @doc """
  Puts the `value` for the given `key` in the Config.
  """
  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end
end

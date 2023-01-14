defmodule Raft.Config do
  @moduledoc """
  Centralized state for a raft server
  """
  use Agent
  require Logger

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  @doc """
  Starts a new bucket.
  """
  def start_link(_opts) do
    Logger.info("Starting #{__MODULE__} agent")
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec get(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get(bucket, key) do
    Agent.get(bucket, &Map.get(&1, key))
  end

  @spec put(atom | pid | {atom, any} | {:via, atom, any}, any, any) :: :ok
  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def put(bucket, key, value) do
    Agent.update(bucket, &Map.put(&1, key, value))
  end
end

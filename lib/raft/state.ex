defmodule Raft.State do
  @moduledoc """
  Struct with all the raft state attributes
  """
  require Logger

  @derive {Poison.Encoder, only: [:current_term, :voted_for, :logs]}

  defstruct current_term: 1,
            membership_state: :follower,
            voted_for: nil,
            logs: [],
            last_index: 0,
            commit_index: 0,
            last_applied: 0,
            next_index: [],
            votes: [],
            election_timer_ref: nil,
            heartbeat_timer_ref: nil

  @spec save(String.t(), Raft.State) :: :ok | {:error, String.t()}
  @doc """
  iex> :ok = Raft.State.save(%Raft.State{})
  """
  def save(path \\ "/tmp/.raft.state", state) when is_struct(state, Raft.State) do
    case Poison.encode(state) do
      {:ok, json} ->
        case File.write(path, json) do
          :ok -> :ok
          {:error, err} -> {:error, err}
        end
      {:error, err} -> {:error, err}
    end
  end

  @spec load(String.t()) :: {:ok, Raft.State} | {:error, String.t()}
  @doc """
  iex> {:ok, state} = Raft.State.load()
  """
  def load(path \\ "/tmp/.raft.state") do
    case File.read(path) do
      {:ok, json} ->
        case Poison.decode(json, as: %Raft.State{}) do
          {:ok, state} -> {:ok, state}
          {:error, err} ->
            {:error, "Error parsing state: #{inspect(err)}"}
          end
      {:error, err} ->
        {:error, "Error parsing state: #{inspect(err)}"}
    end
  end

  @spec update_next_index(list, Integer.t(), any) :: list
  def update_next_index(next_index, id, value) do
    server_index = next_index
      |> Enum.find_index(fn elem ->
        elem.server_id == id
      end)
      |> Kernel.||(length(next_index))

    next_index
      |> List.delete_at(server_index)
      |> List.insert_at(server_index, %{server_id: id, value: value})
  end
end

defmodule Raft.State do
  @moduledoc """
  Struct with all the raft state attributes
  """
  require Logger

  @derive {Poison.Encoder, only: [:current_term, :voted_for, :logs]}

  defstruct current_term: 1,
            membership_state: :follower,
            voted_for: nil,
            last_vote_term: 0,
            logs: [],
            last_applied: 0,
            commit_index: 0,
            next_index: [],
            leader_id: nil,
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

  def update_next_index(state, id, index, term) do
    server_index = state.next_index
      |> Enum.find_index(fn elem ->
        elem.server_id == id
      end)
      |> Kernel.||(length(state.next_index))

    state.next_index
      |> List.delete_at(server_index)
      |> List.insert_at(server_index, %{server_id: id, index: index, term: term })
  end

  def get_follower_data(state, peer) do
    Enum.find(
      state.next_index,
      %{index: state.last_applied, term: state.current_term},
      fn follower -> follower.server_id == peer end
    )
  end

  def get_logs_for_follower(logs, index) do
    Enum.filter(
      logs,
      fn log -> log.index > index end
    )
  end

  def get_last_log(state) do
    state.logs
      |> Enum.sort(fn l1, l2 -> l1.term > l2.term end)
      |> Enum.at(0, %{index: 0, term: 0})
  end

  def initialize_next_index_for_leader(state, peers) do
    Enum.map(
      peers,
      fn peer -> %{
          server_id: peer.peer,
          index: state.last_applied,
          term: find_log(state.logs, state.current_term, state.last_applied).term
        } end
    )
  end

  def find_log(logs, default_term, index) do
    Enum.find(logs, %{term: default_term}, fn log -> log.index == index end)
  end

  def update(state) do
    old_state = Raft.Config.get("state")
    new_state = Map.merge(old_state, state)
    Raft.Config.put("state", new_state)
    new_state
  end
end

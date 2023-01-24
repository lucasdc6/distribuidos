defmodule Raft.State do
  @moduledoc """
  Struct with all the raft state attributes
  """
  defstruct current_term: 1,
            membership_state: :follower,
            voted_for: nil,
            logs: [],
            last_index: 0,
            commit_index: 0,
            last_applied: 0,
            next_index: [],
            votes: []

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

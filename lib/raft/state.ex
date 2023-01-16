defmodule Raft.State do
  @moduledoc """
  Struct with all the raft state attributes
  """
  defstruct current_term: 0, membership_state: :follower, voted_for: []
end

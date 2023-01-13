defmodule Raft.State do
  defstruct current_term: 0, membership_state: :follower
end

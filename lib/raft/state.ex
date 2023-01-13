defmodule Raft.State do
  import Record

  @type state :: record(:state, current_term: integer, membership_state: atom)
  defrecord(:state, current_term: 0, membership_state: :follower)
end

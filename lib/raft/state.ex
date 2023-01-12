defmodule Raft.State do
  import Record

  defrecord(:state, current_term: 0, membership_state: :follower)

  def init() do
    state()
  end

  def current_term(s, current_term) do
    state(s, current_term: current_term)
  end

  def current_term(s) do
    state(s, :current_term)
  end

  def membership(s, membership) do
    state(s, membership_state: membership)
  end

  def membership(s) do
    state(s, :membership_state)
  end
end

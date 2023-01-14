defmodule DistribuidosTest do
  use ExUnit.Case

  test "greets the world" do
    state = %Raft.State{current_term: 10}
    Raft.Server.init(state)
  end
end

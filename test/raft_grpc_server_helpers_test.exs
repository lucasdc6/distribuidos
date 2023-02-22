defmodule RaftGrpcServerHelpersTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest Raft

  setup do
    children = [
      {
        Raft.Config,
        id: Raft.Config
      }
    ]
    # Configure supervisor strategy and name
    opts = [strategy: :one_for_one, name: Raft]
    # Start process
    Supervisor.start_link(children, opts)

    :ok
  end

  test "request a vote with a newer term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 2,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 1,
      membership_state: :follower
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: true
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert %Raft.State{state | voted_for: 1, current_term: 2} == Raft.Config.get("state")
  end

  test "request a vote with a newer term to an elected leader" do
    request = Raft.Server.RequestVoteParams.new(
      term: 2,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 1,
      membership_state: :leader
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: true
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert %Raft.State{state | voted_for: 1, current_term: 2, membership_state: :follower} == Raft.Config.get("state")
  end

  test "request a vote with the same term and without an elected leader" do
    request = Raft.Server.RequestVoteParams.new(
      term: 1,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 1,
      membership_state: :follower
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: true
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert %Raft.State{state | voted_for: 1, current_term: 1} == Raft.Config.get("state")
  end

  test "request a vote with the same term and with an elected leader" do
    request = Raft.Server.RequestVoteParams.new(
      term: 1,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 1,
      membership_state: :follower,
      voted_for: 2
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: false
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert state == Raft.Config.get("state")
  end

  test "request a vote from the elected leader with the same term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 1,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 1,
      membership_state: :follower,
      voted_for: 1
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: true
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert state == Raft.Config.get("state")
  end

  test "request a vote from the elected leader with a newer term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 2,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 1,
      membership_state: :follower,
      voted_for: 1
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: true
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert %Raft.State{state | current_term: 2} == Raft.Config.get("state")
  end

  test "request a vote with an older log index" do
    request = Raft.Server.RequestVoteParams.new(
      term: 3,
      candidate_id: 1,
      last_log_index: 1,
      last_log_term: 2
    )

    state = %Raft.State{
      current_term: 3,
      membership_state: :follower,
      logs: [%{index: 1, value: 1, term: 1}, %{index: 2, value: 1, term: 3}]
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: false
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert state == Raft.Config.get("state")
  end

  test "request a vote with an older log term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 2,
      candidate_id: 1,
      last_log_index: 1,
      last_log_term: 1
    )

    state = %Raft.State{
      current_term: 1,
      membership_state: :follower,
      logs: [%{index: 1, value: 1, term: 1}, %{index: 2, value: 1, term: 1}]
    }
    Raft.Config.put("state", state)

    reply = Raft.Server.RequestVoteReply.new(
      term: request.term,
      vote_granted: false
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert state == Raft.Config.get("state")
  end
end

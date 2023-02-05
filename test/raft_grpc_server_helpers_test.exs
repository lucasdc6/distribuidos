defmodule RaftGrpcServerHelpersTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest Raft

  test "process_vote for a request term older than the state term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 1,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 2
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: false
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Reject vote because it's an older term - request.term(#{request.term}) < state.current_term(#{state.current_term})"
  end

  test "process_vote for a duplicate request for the same term and candidate" do
    request = Raft.Server.RequestVoteParams.new(
      term: 3,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 2,
      last_vote_term: 3,
      voted_for: 1
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: true
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Duplicate request_vote for same term: #{request.term}"
  end

  test "process_vote for a duplicate request for the same term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 3,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 2,
      last_vote_term: 3,
      voted_for: 2
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: false
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Duplicate request_vote for candidate: #{request.candidate_id}"
  end

  test "process_vote for a request term equal to last_vote_term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 3,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 2,
      last_vote_term: 3,
      voted_for: 6
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: false
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
  end

  test "process_vote for a request term newer than the state term and last_vote_term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 3,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 2,
      last_vote_term: 2,
      voted_for: 6
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: true
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
  end
end

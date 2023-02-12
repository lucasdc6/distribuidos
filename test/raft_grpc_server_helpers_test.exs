defmodule RaftGrpcServerHelpersTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest Raft

  # https://github.com/hashicorp/raft/blob/main/raft.go#L1575
  test "process_vote with an elected leader" do
    request = Raft.Server.RequestVoteParams.new(
      term: 1,
      candidate_id: 1
    )

    state = %Raft.State{
      current_term: 1,
      leader_id: 2
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: false
    )

    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Rejecting vote request since we have a leader (#{state.leader_id})"
  end

  # https://github.com/hashicorp/raft/blob/main/raft.go#L1584
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

  # https://github.com/hashicorp/raft/blob/main/raft.go#L1589
  test "process_vote for a request term newer than the state term - lost leadership" do
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
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Lost leadership because received a request_vote with a newer term"
  end

  # https://github.com/hashicorp/raft/blob/main/raft.go#L1623
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
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Duplicate request_vote for same term: #{request.term}"
  end

  # https://github.com/hashicorp/raft/blob/main/raft.go#L1625
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
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Duplicate request_vote for candidate: #{request.candidate_id}"
  end

  # https://github.com/hashicorp/raft/blob/main/raft.go#L1633
  test "process_vote for a request last_log_term older than state last log term" do
    request = Raft.Server.RequestVoteParams.new(
      term: 4,
      candidate_id: 1,
      last_log_index: 2,
      last_log_term: 2
    )

    state = %Raft.State{
      current_term: 3,
      last_vote_term: 3,
      logs: [
        %{index: 1, term: 1, command: 1},
        %{index: 3, term: 4, command: 1},
        %{index: 2, term: 2, command: 1}
      ],
      voted_for: 1
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: false
    )
    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Rejecting vote request since our last term is greater"
  end

  # https://github.com/hashicorp/raft/blob/main/raft.go#L1641
  test "process_vote for a request last_log_index older than state last log index" do
    request = Raft.Server.RequestVoteParams.new(
      term: 4,
      candidate_id: 1,
      last_log_index: 4,
      last_log_term: 4
    )

    state = %Raft.State{
      current_term: 3,
      last_vote_term: 3,
      logs: [
        %{index: 1, term: 1, command: 1},
        %{index: 3, term: 4, command: 1},
        %{index: 2, term: 2, command: 1},
        %{index: 4, term: 4, command: 1},
        %{index: 5, term: 4, command: 1}
      ],
      voted_for: 1
    }

    reply = Raft.Server.RequestVoteReply.new(
      term: state.current_term,
      vote_granted: false
    )
    assert reply == Raft.GRPC.Server.process_vote(request, state)
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Rejecting vote request since our last index is greater"
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
    assert capture_log(fn -> Raft.GRPC.Server.process_vote(request, state) end) =~ "Duplicate request_vote for same term: #{request.term}"
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

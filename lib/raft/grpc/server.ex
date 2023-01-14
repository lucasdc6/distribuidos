defmodule Raft.GRPC.Server do
  use GRPC.Server, service: Raft.Server.GRPC.Service
  require Raft.Server

  @spec request_vote(Raft.Server.RequestVoteParams.t(), GRPC.Server.Stream.t())
        :: Raft.Server.RequestVoteReply.t()
  def request_vote(request, _stream) do
    metadata = Raft.Config.get("metadata")
    state = Raft.Config.get("state")
    Raft.Server.RequestVoteReply.new(
      server_id: Raft.Server.metadata(metadata, :id),
      vote: state.current_term < request.current_term
    )
  end

  def set_membership(request, _stream) do
    state = Raft.Config.get("state")

    if request.membership_state in ["follower", "candidate", "leader", "shutdown"] do
      Raft.Config.put("state", %Raft.State{current_term: state.current_term, membership_state: String.to_atom(request.membership_state)})
      Raft.Server.SetMembershipReply.new(
        result: true
      )
    else
      Raft.Server.SetMembershipReply.new(
        result: false
      )
    end
  end
end

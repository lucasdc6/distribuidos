defmodule Raft.CLI do
  require Logger

  @spec help(String.t()) :: :ok
  def help(name) do
    IO.puts """
    Usage: #{name} [OPTIONS]

    Options:
      -p, --port        Set the grpc server port
      -h, --help        Show this help
      -s, --state-path  Path to the state. Default to /tmp/.raft.state
      --peer            Peer direction
      -v, --loglevel    Set the log level
                        The supported levels, ordered by importance, are:
                          * emergency - when system is unusable, panics
                          * alert - for alerts, actions that must be taken immediately, ex. corrupted database
                          * critical - for critical conditions
                          * error - for errors
                          * warning - for warnings
                          * notice - for normal, but significant, messages
                          * info - for information of any kind
                          * debug - for debug-related messages
    Examples:
      Raft server with peers
        #{name} --peer=server02:50051 --peer=server03:50051
      Raft server with debug log level
        #{name} -v debug
      Raft server with custom state file path
        #{name} --state-path /etc/raft/state
    """
  end

  @spec main(any) :: none
  def main(args) do
    options = [
      strict: [
        port: :integer,
        loglevel: :string,
        statepath: :string,
        help: :boolean,
        peer: [:string, :keep]
      ],
      aliases: [
        p: :port,
        v: :loglevel,
        s: :statepath,
        h: :help
      ],
    ]
    { opts, _, _ } = OptionParser.parse(args, options)

    if opts[:help] do
      name = Path.basename(:escript.script_name)
      help(name)
      exit(:shutdown)
    end

    if opts[:loglevel] do
      Logger.configure(level: String.to_atom(opts[:loglevel]))
    else
      Logger.configure(level: :notice)
    end

    statepath = opts[:statepath] || "/tmp/.raft.state"
    state = case Raft.State.load(statepath) do
      {:ok, state} ->
        Logger.info("Loaded state from #{statepath}")
        state
      {:error, err} ->
        Logger.error("Error loading state from #{statepath} - initializing default state")
        Logger.debug(err)
        %Raft.State{}
    end

    Raft.Server.init(state, opts)
  end
end

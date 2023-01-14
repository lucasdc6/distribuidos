defmodule Raft.CLI do
  @spec help(String.t()) :: :ok
  def help(name) do
    IO.puts """
    Usage: #{name} [OPTIONS]

    Options:
      -p, --port      Set the grpc server port
      -h, --help      Show this help
      -v, --loglevel  Set the log level
                      The supported levels, ordered by importance, are:
                        * emergency - when system is unusable, panics
                        * alert - for alerts, actions that must be taken immediately, ex. corrupted database
                        * critical - for critical conditions
                        * error - for errors
                        * warning - for warnings
                        * notice - for normal, but significant, messages
                        * info - for information of any kind
                        * debug - for debug-related messages
    """
  end

  @spec main(any) :: none
  def main(args) do
    options = [
      strict: [
        port: :integer,
        loglevel: :string,
        help: :boolean,
        peer: [:string, :keep],
      ],
      aliases: [
        p: :port,
        v: :loglevel,
        h: :help,
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

    state = %Raft.State{}
    Raft.Server.init(state, opts)
  end
end

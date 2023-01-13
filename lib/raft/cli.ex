defmodule Raft.CLI do
  def help(name) do
    IO.puts """
    Usage: #{name} [OPTIONS]

    Options:
      -h, --host      Set the listen host
      -p, --port      Set the grpc server port
      -v, --verbose   Enable the verbose mode
      --help          Show this help
    """
  end

  def main(args) do
    options = [
      strict: [
        host: :string,
        port: :string,
        verbose: :string,
        help: :boolean,
      ],
      aliases: [
        h: :host,
        p: :port,
        v: :verbose,
      ],
    ]
    { opts, _, _ } = OptionParser.parse(args, options)

    if opts[:help] do
      name = Path.basename(:escript.script_name)
      help(name)
      exit(:shutdown)
    end

    state = %Raft.State{}
    Raft.Server.init(state)
  end
end


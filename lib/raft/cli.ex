defmodule Raft.CLI do
  require Raft.State

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
      { _, cwd } = File.cwd()
      name = Path.basename(cwd)
      help(name)
      exit(:shutdown)
    end

    state = Raft.State.state()
    Raft.Server.init(state)
  end
end


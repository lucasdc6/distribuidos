defmodule Raft.CLI do
  def main(args) do
    options = [
      strict: [
        host: :string,
        port: :string,
        verbose: :string,
        id: :string,
      ],
      aliases: [
        h: :host,
        p: :port,
        v: :verbose,
      ],
    ]
    {opts,_,_}= OptionParser.parse(args, options)

    state = Raft.State.init()
    Raft.Server.init(opts[:id], state)
  end
end


defmodule Distribuidos.MixProject do
  use Mix.Project

  def project do
    [
      app: :distribuidos,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Raft.CLI],
      test_coverage: [
        ignore_modules: ignore_modules()
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:grpc, git:  "https://github.com/elixir-grpc/grpc"},
      {:protobuf, "~> 0.11"},
      {:poison, "~> 5.0"}
    ]
  end

  defp ignore_modules do
    [
      # Ignore GRPC
      Raft.Server.GRPC.Stub,
      Raft.Server.GRPC.Service,
      Raft.GRPC.Endpoint,
      Raft.Client
    ]
  end
end

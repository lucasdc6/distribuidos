import Config

config :logger, :console,
  metadata: [
    :file,
    :line,
  ]

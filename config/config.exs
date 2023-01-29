import Config

config :logger, :console,
  level: :notice,
  metadata: [
    :file,
    :line,
  ]

import Config

config :logger, :console,
  level: :debug,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

config :commons,
  ecto_repos: [Aesir.Repo]

config :commons, Aesir.Repo,
  database: "aesir_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :account_server,
  port: 6901

config :char_server,
  port: 6121,
  server_config: %{
    name: System.get_env("CHAR_SERVER_NAME", "Aesir"),
    cluster_id: System.get_env("CHAR_SERVER_CLUSTER", "default")
  }

config :zone_server,
  port: 5121

config :libcluster,
  topologies: [
    aesir: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: [:"account@127.0.0.1", :"char@127.0.0.1", :"zone@127.0.0.1"]
      ]
    ]
  ]

config :commons, :memento_cluster,
  nodes: [:"account@127.0.0.1", :"char@127.0.0.1", :"zone@127.0.0.1"],
  auto_cluster: true,
  table_load_timeout: 60_000

config :mnesia,
  dir: ~c".mnesia/#{Mix.env()}/#{node()}"

import_config "#{config_env()}.exs"

import Config

topologies =
  case config_env() do
    :test ->
      []

    _ ->
      [
        aesir: [
          strategy: Cluster.Strategy.Epmd,
          config: [
            hosts: [:"account@127.0.0.1", :"char@127.0.0.1", :"zone@127.0.0.1"],
            timeout: 5_000
          ]
        ]
      ]
  end

config :libcluster, topologies: topologies

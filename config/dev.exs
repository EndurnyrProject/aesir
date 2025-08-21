import Config

config :libcluster,
  topologies: [
    aesir: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: [:"account@127.0.0.1", :"char@127.0.0.1", :"zone@127.0.0.1"]
      ]
    ]
  ]

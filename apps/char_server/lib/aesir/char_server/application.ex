defmodule Aesir.CharServer.Application do
  @moduledoc false

  use Application

  require Logger

  alias Aesir.CharServer.Config.Network, as: NetworkConfig
  alias Aesir.CharServer.Config.ServerInfo, as: ServerInfoConfig
  alias Aesir.Commons.SessionManager

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: Aesir.CharServer.QuicConnSup, strategy: :one_for_one},
      {Aesir.Commons.Network.QuicListener,
       name: :char_server_quic,
       port: NetworkConfig.port(),
       impl_module: Aesir.CharServer,
       conn_sup: Aesir.CharServer.QuicConnSup}
    ]

    opts = [strategy: :one_for_one, name: Aesir.CharServer.Supervisor]

    children
    |> Supervisor.start_link(opts)
    |> tap(fn
      {:ok, _pid} ->
        ip = NetworkConfig.bind_ip()
        port = NetworkConfig.port()

        Logger.info("Aesir CharServer (QUIC) started at #{:inet.ntoa(ip)}:#{port}")

        cluster_id = ServerInfoConfig.cluster_id()
        server_id = "char_server_#{cluster_id}_#{Node.self()}"

        metadata = %{
          name: ServerInfoConfig.name(),
          type: 0,
          new: false,
          cluster_id: cluster_id
        }

        SessionManager.register_server(
          server_id,
          :char_server,
          ip,
          port,
          1000,
          metadata
        )

      {:error, reason} ->
        Logger.error("Failed to start Aesir CharServer: #{inspect(reason)}")
    end)
  end
end

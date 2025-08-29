defmodule Aesir.CharServer.Application do
  @moduledoc false

  use Application

  require Logger

  alias Aesir.CharServer.Config.Network, as: NetworkConfig
  alias Aesir.CharServer.Config.ServerInfo, as: ServerInfoConfig
  alias Aesir.Commons.SessionManager

  @impl true
  def start(_type, _args) do
    ref = make_ref()

    children = [
      {Aesir.Commons.Network.Listener,
       connection_module: Aesir.CharServer,
       packet_registry: Aesir.CharServer.PacketRegistry,
       transport_opts: %{
         socket_opts: [
           port: NetworkConfig.port(),
           ip: NetworkConfig.bind_ip()
         ]
       },
       ref: ref}
    ]

    opts = [strategy: :one_for_one, name: Aesir.CharServer.Supervisor]

    children
    |> Supervisor.start_link(opts)
    |> tap(fn
      {:ok, _pid} ->
        {ip, port} = :ranch.get_addr(ref)

        Logger.info(
          "Aesir CharServer (ref: #{inspect(ref)}) started at #{:inet.ntoa(ip)}:#{port}"
        )

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

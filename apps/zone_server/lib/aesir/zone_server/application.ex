defmodule Aesir.ZoneServer.Application do
  @moduledoc false

  use Application

  require Logger

  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.Config.Network, as: NetworkConfig
  alias Aesir.ZoneServer.Config.ServerInfo, as: ServerInfoConfig

  @impl true
  def start(_type, _args) do
    ref = make_ref()

    children = [
      {Aesir.ZoneServer.EtsTable, name: EtsTables},
      {Registry, keys: :unique, name: Aesir.ZoneServer.MapRegistry},
      {Registry, keys: :unique, name: Aesir.ZoneServer.ProcessRegistry},
      Aesir.ZoneServer.MechanicsSupervisor,
      {Aesir.Commons.Network.Listener,
       connection_module: Aesir.ZoneServer,
       packet_registry: Aesir.ZoneServer.PacketRegistry,
       transport_opts: %{
         socket_opts: [
           port: NetworkConfig.port(),
           ip: NetworkConfig.bind_ip()
         ]
       },
       ref: ref}
    ]

    opts = [strategy: :one_for_one, name: Aesir.ZoneServer.Supervisor]

    children
    |> Supervisor.start_link(opts)
    |> tap(fn
      {:ok, _pid} ->
        {ip, port} = :ranch.get_addr(ref)

        Logger.info(
          "Aesir ZoneServer (ref: #{inspect(ref)}) started at #{:inet.ntoa(ip)}:#{port}"
        )

        cluster_id = ServerInfoConfig.cluster_id()
        server_id = "zone_server_#{cluster_id}_#{Node.self()}"

        metadata = %{
          cluster_id: cluster_id
        }

        SessionManager.register_server(
          server_id,
          :zone_server,
          ip,
          port,
          1000,
          metadata
        )

      {:error, reason} ->
        Logger.error("Failed to start Aesir ZoneServer: #{inspect(reason)}")
    end)
  end
end

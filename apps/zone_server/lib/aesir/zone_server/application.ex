defmodule Aesir.ZoneServer.Application do
  @moduledoc false

  use Application

  require Logger

  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.Config.Network, as: NetworkConfig
  alias Aesir.ZoneServer.Config.ServerInfo, as: ServerInfoConfig

  @impl true
  def start(_type, _args) do
    children =
      [
        {Aesir.ZoneServer.EtsTable, name: EtsTables},
        {Registry, keys: :unique, name: Aesir.ZoneServer.MapRegistry},
        {Registry, keys: :unique, name: Aesir.ZoneServer.ProcessRegistry},
        {Registry, keys: :unique, name: Aesir.ZoneServer.Npc.SessionRegistry},
        {Task.Supervisor, name: Aesir.ZoneServer.TaskSupervisor},
        {Task.Supervisor, name: Aesir.ZoneServer.Npc.InteractionSupervisor},
        Aesir.ZoneServer.Unit.Trade.Supervisor,
        Aesir.ZoneServer.Npc.SessionSupervisor,
        Aesir.ZoneServer.MechanicsSupervisor,
        {DynamicSupervisor, name: Aesir.ZoneServer.QuicConnSup, strategy: :one_for_one},
        {Aesir.Commons.Network.QuicListener,
         name: :zone_server_quic,
         port: NetworkConfig.port(),
         impl_module: Aesir.ZoneServer,
         conn_sup: Aesir.ZoneServer.QuicConnSup}
      ] ++ dev_children()

    opts = [strategy: :one_for_one, name: Aesir.ZoneServer.Supervisor]

    children
    |> Supervisor.start_link(opts)
    |> tap(fn
      {:ok, _pid} ->
        ip = NetworkConfig.bind_ip()
        port = NetworkConfig.port()

        Logger.info("Aesir ZoneServer (QUIC) started at #{:inet.ntoa(ip)}:#{port}")

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

  if Mix.env() == :dev do
    defp dev_children do
      if System.get_env("TIDEWAVE_REPL") == "true" and Code.ensure_loaded?(Bandit) do
        ensure_tidewave_started()
        port = String.to_integer(System.get_env("ZONE_TIDEWAVE_PORT", "13000"))
        [{Bandit, plug: Tidewave, port: port}]
      else
        []
      end
    end

    defp ensure_tidewave_started do
      case Application.ensure_all_started(:tidewave) do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    end
  else
    defp dev_children, do: []
  end
end

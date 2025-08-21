defmodule Aesir.ZoneServer.Application do
  @moduledoc false

  use Application

  require Logger

  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.JobData
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  def start(_type, _args) do
    ref = make_ref()
    maps = initialize_zone()

    children = [
      {Aesir.ZoneServer.EtsTable, name: EtsTables},
      Aesir.ZoneServer.Unit.Player.PlayerSupervisor,
      Aesir.ZoneServer.Mmo.StatusTickManager,
      {Aesir.Commons.Network.Listener,
       connection_module: Aesir.ZoneServer,
       packet_registry: Aesir.ZoneServer.PacketRegistry,
       transport_opts: %{
         socket_opts: [
           port: 5121,
           ip: {192, 168, 178, 101}
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

        server_id = "zone_server_#{Node.self()}"

        metadata = %{
          maps: maps
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

  defp initialize_zone do
    with :ok <- JobData.init(),
         :ok <- StatusStorage.init(),
         :ok <- Interpreter.init(),
         _ <- :ets.new(:zone_players, [:set, :public, :named_table]),
         _ <- :ets.new(:status_instances, [:set, :public, :named_table]),
         {:ok, maps} <- MapCache.init() do
      maps
    end
  end
end

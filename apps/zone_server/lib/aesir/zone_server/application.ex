defmodule Aesir.ZoneServer.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    ref = make_ref()

    children = [
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
          maps: ["prontera", "morocc", "geffen", "payon", "alberta"]
        }

        Aesir.Commons.SessionManager.register_server(
          server_id,
          :zone_server,
          ip,
          port,
          1000,
          metadata
        )
        |> dbg()

      {:error, reason} ->
        Logger.error("Failed to start Aesir ZoneServer: #{inspect(reason)}")
    end)
  end
end

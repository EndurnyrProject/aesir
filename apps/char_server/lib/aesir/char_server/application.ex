defmodule Aesir.CharServer.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    ref = make_ref()

    children = [
      {Aesir.Commons.Network.Listener,
       connection_module: Aesir.CharServer,
       packet_registry: Aesir.CharServer.PacketRegistry,
       transport_opts: %{
         socket_opts: [
           port: 6121,
           ip: {192, 168, 178, 101}
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

        server_config = Application.get_env(:char_server, :server_config, %{})
        server_name = Map.get(server_config, :name, "Aesir")
        cluster_id = Map.get(server_config, :cluster_id, "default")
        server_id = "char_server_#{cluster_id}_#{Node.self()}"

        metadata = %{
          name: server_name,
          type: 0,
          new: false,
          cluster_id: cluster_id
        }

        Aesir.Commons.SessionManager.register_server(
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

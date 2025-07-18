defmodule Aesir.CharServer.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    ref = make_ref()

    children = [
      # Network listener for char server
      {Aesir.Commons.Network.Listener,
       connection_module: Aesir.CharServer,
       packet_registry: Aesir.CharServer.PacketRegistry,
       transport_opts: %{
         socket_opts: [
           port: 6121,
           ip: {127, 0, 0, 1}
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

        # Register this char server with the SessionManager
        server_id = "char_server_#{Node.self()}"
        metadata = %{name: "Aesir", type: 0, new: false}

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
